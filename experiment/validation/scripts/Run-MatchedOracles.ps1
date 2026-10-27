#Requires -Version 5.1
# JCVHT revision (c05a1271): matched oracles on HOST. Do not use the campaign VM.
param(
    [int]$N = 30,
    [string]$RepoRoot = ""
)
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
}
. (Join-Path $RepoRoot "experiment/scripts/collectors/ProcessCollector.ps1")
$pin = Join-Path $RepoRoot "pin\pin.exe"
$dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
$apps = Join-Path $RepoRoot "Resultados\Apps-Teste"
$outDir = Join-Path $PSScriptRoot "results"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Stop-JcvhtLeftovers {
    $names = @(
        "pin", "TestOverhead", "TestAntiDebug", "TestProcessEnum",
        "TestGetEnvironments", "TestMemoryScan", "TestModule32", "TestConcurrentWaits"
    )
    foreach ($n in $names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}

function Invoke-PinApp {
    param(
        [string]$Knobs,
        [string]$ExeName = "",
        [string]$ExePath = "",
        [int]$TimeoutSec = 90
    )
    $exe = if ($ExePath) { $ExePath } else { Join-Path $apps $ExeName }
    Stop-JcvhtLeftovers
    $argList = @("-t", $dll)
    if ($Knobs) { $argList += ($Knobs -split "\s+" | Where-Object { $_ }) }
    $argList += @("--", $exe)
    $tag = [Guid]::NewGuid().ToString("N")
    $outF = Join-Path $env:TEMP "jcvht_out_$tag.txt"
    $errF = Join-Path $env:TEMP "jcvht_err_$tag.txt"
    $observed = Start-ObservedProcess -FilePath $pin -ArgumentList $argList `
        -WorkingDirectory $RepoRoot -StdoutPath $outF -StderrPath $errF
    $p = $observed.Process
    $timedOut = $false
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        $timedOut = $true
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Stop-JcvhtLeftovers
    }
    $code = Complete-ObservedProcess -Observed $observed -WaitMs 500
    $stdout = Get-Content $outF -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content $errF -Raw -ErrorAction SilentlyContinue
    Remove-Item $outF, $errF -Force -ErrorAction SilentlyContinue
    $exitUnknown = (-not $timedOut -and $null -eq $code)
    if ($timedOut) { $code = -2 }
    return [PSCustomObject]@{
        ExitCode = $code
        ExitCodeUnknown = $exitUnknown
        TimedOut = $timedOut
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Parse-Overhead([string]$text) {
    $ticks = $null
    $thr = $null
    $ok = $null
    if ($text -match "Ticks \+ Latencia:\s*([0-9.]+),\s*Limite:\s*([0-9.]+)") {
        $ticks = [double]$Matches[1]
        $thr = [double]$Matches[2]
    }
    if ($text -match "OK - nenhuma anomalia") { $ok = $true }
    elseif ($text -match "Overhead anomalo") { $ok = $false }
    return [PSCustomObject]@{ Ticks = $ticks; Threshold = $thr; BelowThreshold = $ok }
}

$timing = New-Object System.Collections.Generic.List[object]
$arms = @(
    @{ Name = "TMW0"; Knobs = "-q" },
    @{ Name = "GO"; Knobs = "-go -q" },
    @{ Name = "GO_DO"; Knobs = "-go -do -q" }
)
Write-Host "Matched timing N=$N (TMW0 / -go / -go -do) on TestOverhead.exe"
foreach ($arm in $arms) {
    for ($i = 1; $i -le $N; $i++) {
        $r = Invoke-PinApp -Knobs $arm.Knobs -ExeName "TestOverhead.exe"
        $p = Parse-Overhead $r.StdOut
        $errClip = ""
        if ($r.StdErr -match "assertion failed") { $errClip = "PIN_IPC_ASSERT" }
        elseif ($r.TimedOut) { $errClip = "TIMEOUT" }
        $timing.Add([PSCustomObject]@{
            arm = $arm.Name; knobs = $arm.Knobs; attempt = $i
            ticks = $p.Ticks; threshold = $p.Threshold
            below_threshold = $p.BelowThreshold; exit_code = $r.ExitCode
            timed_out = $r.TimedOut; note = $errClip
        })
        Write-Host ("  {0} {1}/{2} ticks={3} below={4} exit={5} {6}" -f $arm.Name, $i, $N, $p.Ticks, $p.BelowThreshold, $r.ExitCode, $errClip)
        $timingPath = Join-Path $outDir "matched_timing_n$N.csv"
        $timing | Export-Csv -Path $timingPath -NoTypeInformation -Encoding UTF8
    }
}

function Summarize($name) {
    $xs = @($timing | Where-Object { $_.arm -eq $name -and $null -ne $_.ticks } | ForEach-Object { [double]$_.ticks })
    $sorted = $xs | Sort-Object
    $med = $sorted[[int](($sorted.Count - 1) / 2)]
    $below = @($timing | Where-Object { $_.arm -eq $name -and $_.below_threshold -eq $true }).Count
    [PSCustomObject]@{
        arm = $name; n = $xs.Count
        median = [Math]::Round($med, 2)
        min = [Math]::Round(($xs | Measure-Object -Minimum).Minimum, 2)
        max = [Math]::Round(($xs | Measure-Object -Maximum).Maximum, 2)
        mean = [Math]::Round(($xs | Measure-Object -Average).Average, 2)
        below_threshold = $below
        rate_below = [Math]::Round(100.0 * $below / [Math]::Max($xs.Count, 1), 1)
    }
}
$summary = @("TMW0", "GO", "GO_DO") | ForEach-Object { Summarize $_ }
$summary | Export-Csv (Join-Path $outDir "matched_timing_summary.csv") -NoTypeInformation -Encoding UTF8
$summary | Format-Table -AutoSize
Write-Host "Wrote $timingPath"

Write-Host "`nFunctional oracles (single run each)"
$func = @(
    @{ Name = "AD_base"; Knobs = "-gdb -q"; Exe = "TestAntiDebug.exe" },
    @{ Name = "AD_treat"; Knobs = "-gdb -dd -q"; Exe = "TestAntiDebug.exe" },
    @{ Name = "PE_base"; Knobs = "-q"; Exe = "TestProcessEnum.exe" },
    @{ Name = "PE_treat"; Knobs = "-dp -q"; Exe = "TestProcessEnum.exe" },
    @{ Name = "PE_da"; Knobs = "-da -q"; Exe = "TestProcessEnum.exe" },
    @{ Name = "EV_base"; Knobs = "-q"; Exe = "TestGetEnvironments.exe" },
    @{ Name = "EV_treat"; Knobs = "-de -q"; Exe = "TestGetEnvironments.exe" },
    @{ Name = "MS_base"; Knobs = "-q"; Exe = "TestMemoryScan.exe" },
    @{ Name = "MS_treat"; Knobs = "-dm -q"; Exe = "TestMemoryScan.exe" },
    @{ Name = "DA_overhead"; Knobs = "-da -q"; Exe = "TestOverhead.exe" }
)
$funcRows = foreach ($f in $func) {
    $r = Invoke-PinApp -Knobs $f.Knobs -ExeName $f.Exe
    $clip = ""
    if ($r.StdOut) {
        $clip = (($r.StdOut -split "`n") | Where-Object { $_ -match "pin\.exe|Resumo|Alerta|OK -|Overhead|ZZZ_|PIN_|memcmp|Ticks" } | Select-Object -First 12) -join " | "
    }
    if ($r.StdErr -match "assertion failed") { $clip = "PIN_IPC_ASSERT " + $clip }
    if ($r.TimedOut) { $clip = "TIMEOUT " + $clip }
    Write-Host ("  {0}: {1}" -f $f.Name, $clip)
    [PSCustomObject]@{ name = $f.Name; knobs = $f.Knobs; exe = $f.Exe; exit = $r.ExitCode; excerpt = $clip }
}
$funcRows | Export-Csv (Join-Path $outDir "functional_oracles.csv") -NoTypeInformation -Encoding UTF8

Write-Host "`nModule32 / concurrent waits (native + Pin)"
$extraExe = @(
    @{ Name = "M32_native"; Knobs = $null; Path = (Join-Path $PSScriptRoot "TestModule32.exe"); Native = $true },
    @{ Name = "M32_pin"; Knobs = "-q"; Path = (Join-Path $PSScriptRoot "TestModule32.exe") },
    @{ Name = "M32_dp"; Knobs = "-dp -q"; Path = (Join-Path $PSScriptRoot "TestModule32.exe") },
    @{ Name = "WAIT_native"; Knobs = $null; Path = (Join-Path $PSScriptRoot "TestConcurrentWaits.exe"); Native = $true },
    @{ Name = "WAIT_go"; Knobs = "-go -q"; Path = (Join-Path $PSScriptRoot "TestConcurrentWaits.exe") },
    @{ Name = "WAIT_go_do"; Knobs = "-go -do -q"; Path = (Join-Path $PSScriptRoot "TestConcurrentWaits.exe") }
)
$extraRows = foreach ($e in $extraExe) {
    if ($e.Native) {
        $tag = [Guid]::NewGuid().ToString("N")
        $outF = Join-Path $env:TEMP "jcvht_out_$tag.txt"
        $errF = Join-Path $env:TEMP "jcvht_err_$tag.txt"
        $p = Start-Process -FilePath $e.Path -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outF -RedirectStandardError $errF
        $stdout = Get-Content $outF -Raw -ErrorAction SilentlyContinue
        Remove-Item $outF, $errF -Force -ErrorAction SilentlyContinue
        $clip = (($stdout -split "`n") | Select-Object -First 8) -join " | "
        Write-Host ("  {0}: {1}" -f $e.Name, $clip)
        [PSCustomObject]@{ name = $e.Name; knobs = "native"; exe = [IO.Path]::GetFileName($e.Path); exit = $p.ExitCode; excerpt = $clip }
    } else {
        $r = Invoke-PinApp -Knobs $e.Knobs -ExePath $e.Path
        $body = if ($r.StdOut) { $r.StdOut } else { $r.StdErr }
        $clip = (($body -split "`n") | Select-Object -First 8) -join " | "
        if ($r.StdErr -match "assertion failed") { $clip = "PIN_IPC_ASSERT " + $clip }
        Write-Host ("  {0}: {1}" -f $e.Name, $clip)
        [PSCustomObject]@{ name = $e.Name; knobs = $e.Knobs; exe = [IO.Path]::GetFileName($e.Path); exit = $r.ExitCode; excerpt = $clip }
    }
}
$extraRows | Export-Csv (Join-Path $outDir "module32_waits.csv") -NoTypeInformation -Encoding UTF8
Write-Host "Done."
