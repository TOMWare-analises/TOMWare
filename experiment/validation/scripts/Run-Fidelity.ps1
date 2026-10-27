#Requires -Version 5.1
# IEEE Access Etapa 6: Q7 fidelity. External observer (NOT FidelityProbe + TOMWare).
# 10 samples x 4 arms (NAT EMPTY TMW0 TMW_ALL) x 3 reps = 120.
# Snapshot DLL of tomware_go. Resume-safe. CSV after every row.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\etapa6_fidelity",
    [int]$Reps = 3,
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
$ioDir = Join-Path $OutDir "io_hashes"
New-Item -ItemType Directory -Force -Path $ioDir | Out-Null
$csvPath = Join-Path $OutDir "fidelity_by_run.csv"

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

function Get-FileMeta([string]$path) {
    if (-not (Test-Path $path)) {
        return @{ sha = ""; bytes = 0 }
    }
    $item = Get-Item $path
    $sha = ""
    if ($item.Length -gt 0) {
        $sha = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
    }
    return @{ sha = $sha; bytes = [int]$item.Length }
}

function Get-ProcSnapshot {
    $names = New-Object System.Collections.Generic.HashSet[string]
    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
        if ($p.ProcessName) { [void]$names.Add($p.ProcessName.ToLower()) }
    }
    return $names
}

function List-WatchFiles {
    $acc = New-Object System.Collections.Generic.List[string]
    $roots = @(
        $env:TEMP,
        "C:\Users\Public",
        (Join-Path $env:USERPROFILE "Desktop"),
        (Join-Path $env:USERPROFILE "Downloads")
    )
    foreach ($root in $roots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        Get-ChildItem $root -File -ErrorAction SilentlyContinue | ForEach-Object {
            $acc.Add($_.FullName.ToLower())
        }
    }
    return $acc
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
Write-Host ("Etapa 6: {0} samples x 4 arms x {1} reps = {2} planned" -f $samples.Count, $Reps, ($samples.Count * 4 * $Reps))
Write-Host ("Timeout {0}s. Observer=external_ps (not FidelityProbe). Resume: {1}" -f $TimeoutSec, $csvPath)
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
    @{ Name = "NAT"; Mode = "native" },
    @{ Name = "EMPTY"; Mode = "empty" },
    @{ Name = "TMW0"; Mode = "tmw0" },
    @{ Name = "TMW_ALL"; Mode = "tmwall" }
)

$ignoreKids = New-Object System.Collections.Generic.HashSet[string]
foreach ($n in @("idle", "system", "pin", "pinbin", "powershell", "pwsh", "conhost", "csrss", "smss", "services", "lsass", "svchost", "explorer", "vmtoolsd", "vmwaretray", "dwm")) {
    [void]$ignoreKids.Add($n)
}

$planned = $samples.Count * 4 * $Reps
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
            $outF = Join-Path $ioDir ($runId + ".out.txt")
            $errF = Join-Path $ioDir ($runId + ".err.txt")
            $file = $null
            $args = @()
            $work = Split-Path -Parent $exe
            if ($arm.Mode -eq "native") {
                $file = $exe
                $args = @()
            } elseif ($arm.Mode -eq "empty") {
                $file = $pin
                $args = @("-t", $empty, "--", $exe)
            } elseif ($arm.Mode -eq "tmw0") {
                $file = $pin
                $args = @("-t", $dll, "-q", "--", $exe)
            } else {
                $file = $pin
                $args = @("-t", $dll, "-da", "-q", "--", $exe)
            }
            $beforeProc = Get-ProcSnapshot
            $beforeFiles = List-WatchFiles
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $obs = $null
            $timedOut = $false
            $code = $null
            $seenKids = New-Object System.Collections.Generic.HashSet[string]
            try {
                $obs = Start-Observed -FilePath $file -ArgumentList $args -WorkDir $work -OutF $outF -ErrF $errF
                $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
                while (-not $obs.Process.HasExited) {
                    if ([DateTime]::UtcNow -gt $deadline) {
                        $timedOut = $true
                        Stop-Process -Id $obs.Process.Id -Force -ErrorAction SilentlyContinue
                        Stop-Leftovers
                        break
                    }
                    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
                        $nm = ""
                        if ($p.ProcessName) { $nm = $p.ProcessName.ToLower() }
                        if ($nm -and -not $ignoreKids.Contains($nm) -and -not $beforeProc.Contains($nm)) {
                            [void]$seenKids.Add($nm)
                        }
                    }
                    Start-Sleep -Milliseconds 400
                }
                $code = Complete-Observed -Obs $obs
            } catch {
                $code = $null
            }
            $sw.Stop()
            if ($timedOut) { $code = -2 }
            $outM = Get-FileMeta $outF
            $errM = Get-FileMeta $errF
            $afterFiles = List-WatchFiles
            $newFiles = New-Object System.Collections.Generic.List[string]
            $beforeSet = New-Object System.Collections.Generic.HashSet[string]
            foreach ($f in $beforeFiles) { [void]$beforeSet.Add($f) }
            foreach ($f in $afterFiles) {
                if (-not $beforeSet.Contains($f)) { $newFiles.Add($f) }
            }
            $kids = @($seenKids)
            [Array]::Sort($kids)
            $kidStr = ($kids -join ";")
            if ($kidStr.Length -gt 240) { $kidStr = $kidStr.Substring(0, 240) }
            $nfStr = ($newFiles -join ";")
            if ($nfStr.Length -gt 240) { $nfStr = $nfStr.Substring(0, 240) }
            $row = [PSCustomObject]@{
                run_id = $runId
                sample_id = $s.sample_id
                group = $s.group
                profile = $s.execution_profile
                sha256 = $s.sha256
                arm = $arm.Name
                attempt = $i
                timeout_sec = $TimeoutSec
                exit_code = $code
                timed_out = $timedOut
                duration_ms = [int][Math]::Round($sw.Elapsed.TotalMilliseconds, 0)
                stdout_sha256 = $outM.sha
                stdout_bytes = $outM.bytes
                stderr_sha256 = $errM.sha
                stderr_bytes = $errM.bytes
                child_proc_count = $seenKids.Count
                child_proc_names = $kidStr
                new_files_count = $newFiles.Count
                new_files = $nfStr
                observer = "external_ps"
            }
            [void]$rows.Add($row)
            $done[$k] = $true
            Save-Csv $rows $csvPath
            Write-Host ("  [{0}/{1}] {2} exit={3} dur_ms={4} out={5} kids={6} files={7}" -f `
                $n, $planned, $runId, $code, $row.duration_ms, $outM.bytes, $seenKids.Count, $newFiles.Count)
        }
    }
}

Write-Host ""
Write-Host "Etapa 6 done (or paused). Copy back:"
Write-Host "  $csvPath"
Write-Host "  $ioDir"
Write-Host ("Rows: {0}" -f $rows.Count)
