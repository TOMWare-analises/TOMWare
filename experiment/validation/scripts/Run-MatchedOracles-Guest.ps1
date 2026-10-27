#Requires -Version 5.1
# IEEE Access Etapa 4: oracles on the VM. Does NOT rerun timing N=30.
# No malware corpus. Save CSV after every row.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\etapa4_oracles",
    [int]$AdReps = 3,
    [int]$TimeoutSec = 90
)
$ErrorActionPreference = "Stop"
$PinTimeoutSec = $TimeoutSec

$pin = Join-Path $RepoRoot "pin\pin.exe"
$dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
$empty = Join-Path $RepoRoot "x64\Release\EmptyPinTool.dll"
$apps = Join-Path $RepoRoot "Resultados\Apps-Teste"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

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
    $names = @(
        "pin", "TestOverhead", "TestAntiDebug", "TestProcessEnum",
        "TestGetEnvironments", "TestMemoryScan", "TestModule32", "TestConcurrentWaits"
    )
    foreach ($n in $names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 400
}

function Invoke-One {
    param(
        [string]$Mode,          # native | empty | tomware | pin_bare
        [string]$Knobs = "",
        [string]$ExePath,
        [int]$TimeoutSec = 90
    )
    Stop-Leftovers
    $tag = [Guid]::NewGuid().ToString("N")
    $outF = Join-Path $env:TEMP "e4_out_$tag.txt"
    $errF = Join-Path $env:TEMP "e4_err_$tag.txt"
    $file = $null
    $args = @()
    $work = $RepoRoot
    if ($Mode -eq "native") {
        $file = $ExePath
        $work = Split-Path -Parent $ExePath
    } elseif ($Mode -eq "empty") {
        $file = $pin
        $args = @("-t", $empty, "--", $ExePath)
    } elseif ($Mode -eq "pin_bare") {
        $file = $pin
        $args = @("--", $ExePath)
    } else {
        $file = $pin
        $args = @("-t", $dll)
        if ($Knobs) { $args += ($Knobs -split "\s+" | Where-Object { $_ }) }
        $args += @("--", $ExePath)
    }
    $obs = Start-Observed -FilePath $file -ArgumentList $args -WorkDir $work -OutF $outF -ErrF $errF
    $timedOut = $false
    if (-not $obs.Process.WaitForExit($TimeoutSec * 1000)) {
        $timedOut = $true
        Stop-Process -Id $obs.Process.Id -Force -ErrorAction SilentlyContinue
        Stop-Leftovers
    }
    $code = Complete-Observed -Obs $obs
    $stdout = Get-Content $outF -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content $errF -Raw -ErrorAction SilentlyContinue
    Remove-Item $outF, $errF -Force -ErrorAction SilentlyContinue
    if ($timedOut) { $code = -2 }
    return [PSCustomObject]@{
        ExitCode = $code
        ExitCodeUnknown = (-not $timedOut -and $null -eq $code)
        TimedOut = $timedOut
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Clip-Text([string]$text, [int]$n = 14) {
    if (-not $text) { return "" }
    return (($text -split "`n" | Where-Object { $_.Trim() } | Select-Object -First $n) -join " | ")
}

function Save-Rows($rows, $name) {
    $path = Join-Path $OutDir $name
    $flat = New-Object System.Collections.ArrayList
    foreach ($r in $rows) { [void]$flat.Add($r) }
    if ($flat.Count -eq 0) { return }
    $flat | Export-Csv -Path $path -NoTypeInformation -Encoding Default
}

# --- preflight ---
$pre = @(
    [PSCustomObject]@{ item = "pin.exe"; path = $pin; exists = (Test-Path $pin) }
    [PSCustomObject]@{ item = "TOMWare.dll"; path = $dll; exists = (Test-Path $dll) }
    [PSCustomObject]@{ item = "EmptyPinTool.dll"; path = $empty; exists = (Test-Path $empty) }
    [PSCustomObject]@{ item = "TestAntiDebug"; path = (Join-Path $apps "TestAntiDebug.exe"); exists = (Test-Path (Join-Path $apps "TestAntiDebug.exe")) }
    [PSCustomObject]@{ item = "timeout_sec_declared"; path = "$PinTimeoutSec"; exists = $true }
)
$m32 = Join-Path $RepoRoot "experiment\validation\scripts\legacy\TestModule32.exe"
$wait = Join-Path $RepoRoot "experiment\validation\scripts\legacy\TestConcurrentWaits.exe"
if (-not (Test-Path $m32)) { $m32 = Join-Path $PSScriptRoot "TestModule32.exe" }
if (-not (Test-Path $wait)) { $wait = Join-Path $PSScriptRoot "TestConcurrentWaits.exe" }
$pre += [PSCustomObject]@{ item = "TestModule32"; path = $m32; exists = (Test-Path $m32) }
$pre += [PSCustomObject]@{ item = "TestConcurrentWaits"; path = $wait; exists = (Test-Path $wait) }
Save-Rows $pre "preflight.csv"
$pre | Format-Table -AutoSize
$missing = @($pre | Where-Object { -not $_.exists })
if ($missing.Count -gt 0) { throw "Missing: $($missing.item -join ', ')" }

# --- 1) Pin probe without -t ---
Write-Host "`n[1] Pin probe without -t (timeout ${PinTimeoutSec}s)"
$probeExe = Join-Path $apps "TestAntiDebug.exe"
$probe = Invoke-One -Mode pin_bare -ExePath $probeExe -TimeoutSec 30
$probeRow = [PSCustomObject]@{
    name = "PIN_BARE"
    knobs = "(none; pin.exe -- exe)"
    timeout_sec = 30
    exit_code = $probe.ExitCode
    timed_out = $probe.TimedOut
    stdout = Clip-Text $probe.StdOut 20
    stderr = Clip-Text $probe.StdErr 20
    pin_condition_valid = $false
    note = "Bare Pin is invalid on this Pin 3.28 build if StartServer/IPC assert or launch fails"
}
Save-Rows @($probeRow) "pin_probe.csv"
Write-Host ("  exit={0} timeout={1}" -f $probe.ExitCode, $probe.TimedOut)
Write-Host ("  stderr: {0}" -f $probeRow.stderr)

# --- 2) AntiDebug N=3 ---
Write-Host "`n[2] AntiDebug N=$AdReps"
$adExe = Join-Path $apps "TestAntiDebug.exe"
$adArms = @(
    @{ Name = "AD_NAT"; Mode = "native"; Knobs = "" },
    @{ Name = "AD_TMW0"; Mode = "tomware"; Knobs = "-q" },
    @{ Name = "AD_GDB"; Mode = "tomware"; Knobs = "-gdb -q" },
    @{ Name = "AD_GDB_DD"; Mode = "tomware"; Knobs = "-gdb -dd -q" }
)
$adRows = New-Object System.Collections.Generic.List[object]
foreach ($arm in $adArms) {
    for ($i = 1; $i -le $AdReps; $i++) {
        $r = Invoke-One -Mode $arm.Mode -Knobs $arm.Knobs -ExePath $adExe -TimeoutSec $PinTimeoutSec
        $row = [PSCustomObject]@{
            name = $arm.Name; knobs = $arm.Knobs; mode = $arm.Mode
            attempt = $i; timeout_sec = $PinTimeoutSec
            exit_code = $r.ExitCode; timed_out = $r.TimedOut
            excerpt = Clip-Text $r.StdOut
        }
        $adRows.Add($row)
        Write-Host ("  {0} {1}/{2} exit={3} {4}" -f $arm.Name, $i, $AdReps, $r.ExitCode, $row.excerpt)
        Save-Rows $adRows "antidebug_n3.csv"
    }
}

# --- 3) -da on the five oracles ---
Write-Host "`n[3] Combined -da on 5 oracles"
$daJobs = @(
    @{ Name = "DA_AD"; Knobs = "-gdb -da -q"; Exe = (Join-Path $apps "TestAntiDebug.exe") },
    @{ Name = "DA_PE"; Knobs = "-da -q"; Exe = (Join-Path $apps "TestProcessEnum.exe") },
    @{ Name = "DA_EV"; Knobs = "-da -q"; Exe = (Join-Path $apps "TestGetEnvironments.exe") },
    @{ Name = "DA_MS"; Knobs = "-da -q"; Exe = (Join-Path $apps "TestMemoryScan.exe") },
    @{ Name = "DA_SK"; Knobs = "-da -q"; Exe = (Join-Path $apps "TestOverhead.exe") }
)
$daRows = New-Object System.Collections.Generic.List[object]
foreach ($j in $daJobs) {
    $r = Invoke-One -Mode tomware -Knobs $j.Knobs -ExePath $j.Exe -TimeoutSec $PinTimeoutSec
    $row = [PSCustomObject]@{
        name = $j.Name; knobs = $j.Knobs; exe = [IO.Path]::GetFileName($j.Exe)
        timeout_sec = $PinTimeoutSec; exit_code = $r.ExitCode
        timed_out = $r.TimedOut; excerpt = Clip-Text $r.StdOut
    }
    $daRows.Add($row)
    Write-Host ("  {0}: {1}" -f $j.Name, $row.excerpt)
    Save-Rows $daRows "da_oracles.csv"
}

# --- 4) Module32 / waits: native, EmptyPin, TMW0 ---
Write-Host "`n[4] Module32 and concurrent waits (timeout ${PinTimeoutSec}s)"
$extra = @(
    @{ Name = "M32_NAT"; Mode = "native"; Knobs = ""; Path = $m32 },
    @{ Name = "M32_EMPTY"; Mode = "empty"; Knobs = ""; Path = $m32 },
    @{ Name = "M32_TMW0"; Mode = "tomware"; Knobs = "-q"; Path = $m32 },
    @{ Name = "M32_DP"; Mode = "tomware"; Knobs = "-dp -q"; Path = $m32 },
    @{ Name = "WAIT_NAT"; Mode = "native"; Knobs = ""; Path = $wait },
    @{ Name = "WAIT_EMPTY"; Mode = "empty"; Knobs = ""; Path = $wait },
    @{ Name = "WAIT_TMW0"; Mode = "tomware"; Knobs = "-q"; Path = $wait },
    @{ Name = "WAIT_GO"; Mode = "tomware"; Knobs = "-go -q"; Path = $wait },
    @{ Name = "WAIT_GO_DO"; Mode = "tomware"; Knobs = "-go -do -q"; Path = $wait }
)
$exRows = New-Object System.Collections.Generic.List[object]
foreach ($e in $extra) {
    $r = Invoke-One -Mode $e.Mode -Knobs $e.Knobs -ExePath $e.Path -TimeoutSec $PinTimeoutSec
    $body = if ($r.StdOut) { $r.StdOut } else { $r.StdErr }
    $row = [PSCustomObject]@{
        name = $e.Name; mode = $e.Mode; knobs = $e.Knobs
        exe = [IO.Path]::GetFileName($e.Path)
        timeout_sec = $PinTimeoutSec; exit_code = $r.ExitCode
        timed_out = $r.TimedOut; excerpt = Clip-Text $body 10
    }
    $exRows.Add($row)
    Write-Host ("  {0}: exit={1} timeout={2} {3}" -f $e.Name, $r.ExitCode, $r.TimedOut, $row.excerpt)
    Save-Rows $exRows "module32_waits.csv"
}

# --- 5) -mc smoke ---
Write-Host "`n[5] Module-counter smoke (-mc)"
$mcf = Join-Path $OutDir "module_events_smoke.json"
if (Test-Path $mcf) { Remove-Item $mcf -Force }
$mc = Invoke-One -Mode tomware -Knobs "-dp -mc -mcf $mcf -q" -ExePath (Join-Path $apps "TestProcessEnum.exe") -TimeoutSec $PinTimeoutSec
$mcExists = Test-Path $mcf
$mcRow = [PSCustomObject]@{
    name = "MC_SMOKE"
    knobs = "-dp -mc -mcf <out> -q"
    exit_code = $mc.ExitCode
    timed_out = $mc.TimedOut
    counters_file_exists = $mcExists
    counters_bytes = if ($mcExists) { (Get-Item $mcf).Length } else { 0 }
    excerpt = Clip-Text $mc.StdOut
}
Save-Rows @($mcRow) "module_counters_smoke.csv"
Write-Host ("  counters_file_exists={0} bytes={1}" -f $mcExists, $mcRow.counters_bytes)

# --- provenance note for N=30 (do not rerun) ---
$n30 = [PSCustomObject]@{
    reused = $true
    host_csv = "experiment/results/oracles/matched_timing_n30.csv"
    sha256 = "76208218f71b37b8bf3411c0a74932752b96dd133d4db102eebbec25c65b9827"
    n = 90
    note = "Do not rerun. Conventional medians: TMW0 2433.285; GO 3083.210 (11/30 below); GO_DO 2104.770 (30/30)."
}
Save-Rows @($n30) "timing_n30_provenance.csv"

Write-Host "`nEtapa 4 done. Copy the folder back to the host:"
Write-Host "  $OutDir"
Write-Host "Files: preflight.csv pin_probe.csv antidebug_n3.csv da_oracles.csv module32_waits.csv module_counters_smoke.csv timing_n30_provenance.csv"
