#Requires -Version 5.1
# IEEE Access Etapa 7: prospective exit-code confirmation, collector v2.1.
# 20 short_lived x 9 arms x 10 reps = 1800.
# Does NOT rewrite the 9000 JSON. Snapshot DLL. Resume-safe.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\etapa7_confirm",
    [int]$Reps = 10,
    [int]$TimeoutSec = 45,
    [string]$SampleList = ""
)
$ErrorActionPreference = "Stop"
$pin = Join-Path $RepoRoot "pin\pin.exe"
$dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
$empty = Join-Path $RepoRoot "x64\Release\EmptyPinTool.dll"
if (-not $SampleList) {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { $OutDir }
    $SampleList = Join-Path $here "sample_list.csv"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$csvPath = Join-Path $OutDir "exitcodes_by_run.csv"

function Join-Args([string[]]$ArgumentList) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($a in @($ArgumentList)) {
        if ($null -eq $a -or $a -eq "") { continue }
        if ($a -match '[\s"]') { $parts.Add(('"{0}"' -f ($a -replace '"', '\"'))) }
        else { $parts.Add([string]$a) }
    }
    return ($parts -join " ")
}

function Start-Observed {
    param([string]$FilePath, [string[]]$ArgumentList, [string]$WorkDir, [string]$OutF, [string]$ErrF)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = Join-Args $ArgumentList
    if ($WorkDir) { $psi.WorkingDirectory = $WorkDir }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $outFs = [IO.File]::Open($OutF, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $errFs = [IO.File]::Open($ErrF, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    return [PSCustomObject]@{
        Process = $proc
        OutFs = $outFs
        ErrFs = $errFs
        OutCopy = $proc.StandardOutput.BaseStream.CopyToAsync($outFs)
        ErrCopy = $proc.StandardError.BaseStream.CopyToAsync($errFs)
    }
}

function Complete-Observed {
    param($Obs, [int]$WaitMs = 2000)
    if ($null -eq $Obs) { return $null }
    $proc = $Obs.Process
    if ($proc -and -not $proc.HasExited) { [void]$proc.WaitForExit($WaitMs) }
    try { if ($Obs.OutCopy) { [void]$Obs.OutCopy.Wait(2000) } } catch {}
    try { if ($Obs.ErrCopy) { [void]$Obs.ErrCopy.Wait(2000) } } catch {}
    foreach ($s in @($Obs.OutFs, $Obs.ErrFs)) {
        if ($s) { try { $s.Flush(); $s.Dispose() } catch {} }
    }
    if ($proc -and $proc.HasExited) {
        try { $proc.WaitForExit(); return $proc.ExitCode } catch { return $null }
    }
    return $null
}

function Stop-Leftovers {
    Get-Process -Name pin, pinbin -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
}

function Find-SampleExe([string]$Sha256) {
    $shaU = $Sha256.ToUpper()
    $shaL = $Sha256.ToLower()
    $dirs = @(
        (Join-Path $RepoRoot "samples\benign"),
        (Join-Path $RepoRoot "samples\infected"),
        (Join-Path $RepoRoot "malwares\infected"),
        (Join-Path $RepoRoot "malwares\benign")
    )
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { continue }
        foreach ($n in @("$shaL.exe", "$shaU.exe", $shaL, $shaU)) {
            $p = Join-Path $d $n
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

function Get-Outcome([object]$code, [bool]$timedOut) {
    if ($timedOut) {
        return [PSCustomObject]@{ reason = "timeout"; crash = $false; exit_code = -2 }
    }
    if ($null -eq $code -or $code -eq "") {
        return [PSCustomObject]@{ reason = "exited_before_limit_exit_code_unknown"; crash = $false; exit_code = $null }
    }
    $n = 0
    try { $n = [int]$code } catch {
        return [PSCustomObject]@{ reason = "exited_before_limit_exit_code_unknown"; crash = $false; exit_code = $null }
    }
    if ($n -eq -2) {
        return [PSCustomObject]@{ reason = "timeout"; crash = $false; exit_code = -2 }
    }
    if ($n -lt 0 -or $n -gt 65535) {
        return [PSCustomObject]@{ reason = "exception_crash"; crash = $true; exit_code = $n }
    }
    return [PSCustomObject]@{ reason = "natural_exit"; crash = $false; exit_code = $n }
}

function Save-Csv($rows, $path) {
    $flat = New-Object System.Collections.ArrayList
    foreach ($r in $rows) { [void]$flat.Add($r) }
    if ($flat.Count -eq 0) { return }
    $flat | Export-Csv -Path $path -NoTypeInformation -Encoding Default
}

if (-not (Test-Path $pin)) { throw "pin.exe missing: $pin" }
if (-not (Test-Path $dll)) { throw "TOMWare.dll missing: $dll" }
if (-not (Test-Path $empty)) { throw "EmptyPinTool.dll missing: $empty" }
if (-not (Test-Path $SampleList)) { throw "sample_list.csv missing: $SampleList" }

$samples = @(Import-Csv -Path $SampleList)
Write-Host ("Etapa 7: {0} samples x 9 arms x {1} reps = {2} planned" -f $samples.Count, $Reps, ($samples.Count * 9 * $Reps))
Write-Host ("collector_version=2.1.0 Timeout {0}s Resume: {1}" -f $TimeoutSec, $csvPath)
Write-Host ("TOMWare.dll hash={0}" -f (Get-FileHash $dll -Algorithm SHA256).Hash)

$done = @{}
$rows = New-Object System.Collections.ArrayList
if (Test-Path $csvPath) {
    $prev = @(Import-Csv -Path $csvPath)
    foreach ($p in $prev) {
        $k = "{0}|{1}|{2}" -f $p.sample_id, $p.arm, $p.attempt
        $done[$k] = $true
        [void]$rows.Add($p)
    }
    Write-Host ("Resuming: {0} rows already saved" -f $rows.Count)
}

$arms = @(
    @{ Name = "NAT"; Mode = "native"; Knobs = "" },
    @{ Name = "EMPTY"; Mode = "empty"; Knobs = "" },
    @{ Name = "TMW0"; Mode = "tmw"; Knobs = "-q" },
    @{ Name = "TMW_DD"; Mode = "tmw"; Knobs = "-dd -q" },
    @{ Name = "TMW_DP"; Mode = "tmw"; Knobs = "-dp -q" },
    @{ Name = "TMW_DE"; Mode = "tmw"; Knobs = "-de -q" },
    @{ Name = "TMW_DM"; Mode = "tmw"; Knobs = "-dm -q" },
    @{ Name = "TMW_DO"; Mode = "tmw"; Knobs = "-do -q" },
    @{ Name = "TMW_ALL"; Mode = "tmw"; Knobs = "-da -q" }
)

$planned = $samples.Count * 9 * $Reps
$n = $rows.Count
foreach ($s in $samples) {
    $exe = Find-SampleExe $s.sha256
    if (-not $exe) {
        Write-Host ("MISSING exe {0} {1}" -f $s.sample_id, $s.sha256)
        continue
    }
    Write-Host ("  using {0} -> {1}" -f $s.sample_id, $exe)
    for ($i = 1; $i -le $Reps; $i++) {
        foreach ($arm in $arms) {
            $k = "{0}|{1}|{2}" -f $s.sample_id, $arm.Name, $i
            if ($done.ContainsKey($k)) { continue }
            $n++
            $runId = "{0}_{1}_{2:00}" -f $s.sample_id, $arm.Name, $i
            Stop-Leftovers
            $tag = [Guid]::NewGuid().ToString("N")
            $outF = Join-Path $env:TEMP "e7_out_$tag.txt"
            $errF = Join-Path $env:TEMP "e7_err_$tag.txt"
            $file = $null
            $args = @()
            $work = Split-Path -Parent $exe
            if ($arm.Mode -eq "native") {
                $file = $exe
            } elseif ($arm.Mode -eq "empty") {
                $file = $pin
                $args = @("-t", $empty, "--", $exe)
            } else {
                $file = $pin
                $args = @("-t", $dll)
                $args += ($arm.Knobs -split "\s+" | Where-Object { $_ })
                $args += @("--", $exe)
            }
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $obs = $null
            $timedOut = $false
            $code = $null
            try {
                $obs = Start-Observed -FilePath $file -ArgumentList $args -WorkDir $work -OutF $outF -ErrF $errF
                if (-not $obs.Process.WaitForExit($TimeoutSec * 1000)) {
                    $timedOut = $true
                    Stop-Process -Id $obs.Process.Id -Force -ErrorAction SilentlyContinue
                    Stop-Leftovers
                }
                $code = Complete-Observed -Obs $obs
            } catch {
                $code = $null
            }
            $sw.Stop()
            Remove-Item $outF, $errF -Force -ErrorAction SilentlyContinue
            $o = Get-Outcome -code $code -timedOut $timedOut
            $row = [PSCustomObject]@{
                run_id = $runId
                sample_id = $s.sample_id
                group = $s.group
                profile = $s.execution_profile
                sha256 = $s.sha256
                arm = $arm.Name
                attempt = $i
                timeout_sec = $TimeoutSec
                collector_version = "2.1.0"
                exit_code = $o.exit_code
                timed_out = $timedOut
                crash = $o.crash
                audited_outcome = $o.reason
                duration_ms = [int][Math]::Round($sw.Elapsed.TotalMilliseconds, 0)
            }
            [void]$rows.Add($row)
            $done[$k] = $true
            Save-Csv $rows $csvPath
            Write-Host ("  [{0}/{1}] {2} exit={3} crash={4} {5}" -f `
                $n, $planned, $runId, $o.exit_code, $o.crash, $o.reason)
        }
    }
}

Write-Host ""
Write-Host "Etapa 7 done (or paused). Copy back:"
Write-Host "  $csvPath"
Write-Host ("Rows: {0}" -f $rows.Count)
