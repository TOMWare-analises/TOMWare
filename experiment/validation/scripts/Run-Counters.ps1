#Requires -Version 5.1
# IEEE Access Etapa 5: 30 short-lived x 2 arms x 10 reps = 600 counter runs.
# TMW0_COUNT = modules off + -mc. TMW_ALL_COUNT = -da + -mc.
# Resume-safe. Saves CSV after every row. No snapshot revert.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\etapa5_counters",
    [int]$Reps = 10,
    [int]$TimeoutSec = 45,
    [string]$SampleList = ""
)
$ErrorActionPreference = "Stop"
$pin = Join-Path $RepoRoot "pin\pin.exe"
$dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
if (-not $SampleList) {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { $OutDir }
    $SampleList = Join-Path $here "sample_list.csv"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$jsonDir = Join-Path $OutDir "raw_json"
New-Item -ItemType Directory -Force -Path $jsonDir | Out-Null
$csvPath = Join-Path $OutDir "module_events_by_run.csv"

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
        (Join-Path $RepoRoot "malwares\benign"),
        (Join-Path $RepoRoot "malwares\infected")
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

function Flag([int]$n) { if ($n -gt 0) { 1 } else { 0 } }

function Read-Counters([string]$path) {
    $empty = @{
        json_ok = 0
        ad_init = 0; ad_san = 0; ad_bd_after = -1
        pe_calls = 0; pe_exam = 0; pe_filt = 0; pe_mod_exam = 0; pe_mod_filt = 0
        env_exam = 0; env_found = 0; env_san = 0
        mc_int = 0; mc_match = 0; mc_mod = 0
        sk_sleep = 0; sk_time = 0; sk_corr = 0
    }
    if (-not (Test-Path $path)) { $empty.json_ok = 0; return $empty }
    try {
        $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $empty
    }
    return @{
        json_ok = 1
        ad_init = [int]$j.antidebug.initializations
        ad_san = [int]$j.antidebug.sanitizations
        ad_bd_after = [int]$j.antidebug.being_debugged_after
        pe_calls = [int]$j.process_enum.calls_intercepted
        pe_exam = [int]$j.process_enum.processes_examined
        pe_filt = [int]$j.process_enum.processes_filtered
        pe_mod_exam = [int]$j.process_enum.modules_examined
        pe_mod_filt = [int]$j.process_enum.modules_filtered
        env_exam = [int]$j.sanitize_env.entries_examined
        env_found = [int]$j.sanitize_env.pin_entries_found
        env_san = [int]$j.sanitize_env.entries_sanitized
        mc_int = [int]$j.memcmp_mask.comparisons_intercepted
        mc_match = [int]$j.memcmp_mask.signatures_matched
        mc_mod = [int]$j.memcmp_mask.responses_modified
        sk_sleep = [int]$j.skew_mask.sleep_calls_intercepted
        sk_time = [int]$j.skew_mask.time_queries_intercepted
        sk_corr = [int]$j.skew_mask.corrections_applied
    }
}

function Save-Csv($rows, $path) {
    $flat = New-Object System.Collections.ArrayList
    foreach ($r in $rows) { [void]$flat.Add($r) }
    if ($flat.Count -eq 0) { return }
    $flat | Export-Csv -Path $path -NoTypeInformation -Encoding Default
}

if (-not (Test-Path $pin)) { throw "pin.exe missing: $pin" }
if (-not (Test-Path $dll)) { throw "TOMWare.dll missing: $dll" }
if (-not (Test-Path $SampleList)) { throw "sample_list.csv missing: $SampleList" }

$pinDir = Split-Path -Parent $pin
$pinBin = Join-Path $pinDir "intel64\bin"
$env:PIN_ROOT = $pinDir
if (Test-Path $pinBin) {
    $env:PATH = ($pinBin + ";" + $pinDir + ";" + $env:PATH)
    $pinBinExe = Join-Path $pinBin "pin.exe"
    if (Test-Path $pinBinExe) { $pin = $pinBinExe }
} else {
    $env:PATH = ($pinDir + ";" + $env:PATH)
}
Write-Host ("PIN_ROOT={0}" -f $env:PIN_ROOT)
Write-Host ("pin.exe={0}" -f $pin)

$samples = @(Import-Csv -Path $SampleList)
Write-Host ("Etapa 5: {0} samples x 2 arms x {1} reps = {2} planned" -f $samples.Count, $Reps, ($samples.Count * 2 * $Reps))
Write-Host ("Timeout {0}s. Resume file: {1}" -f $TimeoutSec, $csvPath)

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
    @{ Name = "TMW0_COUNT"; KnobsPrefix = "-q" },
    @{ Name = "TMW_ALL_COUNT"; KnobsPrefix = "-da -q" }
)

$planned = $samples.Count * 2 * $Reps
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
            $mcf = Join-Path $jsonDir ($runId + ".json")
            if (Test-Path $mcf) { Remove-Item $mcf -Force }
            Stop-Leftovers
            $tag = [Guid]::NewGuid().ToString("N")
            $outF = Join-Path $env:TEMP "e5_out_$tag.txt"
            $errF = Join-Path $env:TEMP "e5_err_$tag.txt"
            $knobParts = @("-t", $dll)
            $knobParts += ($arm.KnobsPrefix -split "\s+" | Where-Object { $_ })
            $knobParts += @("-mc", "1", "-mcf", $mcf, "--", $exe)
            $obs = $null
            $timedOut = $false
            $code = $null
            $stderrTail = ""
            $workDir = $RepoRoot
            try {
                $obs = Start-Observed -FilePath $pin -ArgumentList $knobParts -WorkDir $workDir -OutF $outF -ErrF $errF
                if (-not $obs.Process.WaitForExit($TimeoutSec * 1000)) {
                    $timedOut = $true
                    Stop-Process -Id $obs.Process.Id -Force -ErrorAction SilentlyContinue
                    Stop-Leftovers
                }
                $code = Complete-Observed -Obs $obs
            } catch {
                $code = $null
            }
            if ($timedOut) { $code = -2 }
            $waitUntil = (Get-Date).AddSeconds(3)
            while ((-not (Test-Path $mcf)) -and ((Get-Date) -lt $waitUntil)) {
                if (-not (Get-Process -Name pin, pinbin -ErrorAction SilentlyContinue)) { break }
                Start-Sleep -Milliseconds 200
            }
            if (-not (Test-Path $mcf)) {
                foreach ($alt in @(
                    (Join-Path $workDir "module_events.json"),
                    (Join-Path (Split-Path -Parent $exe) "module_events.json"),
                    (Join-Path $pinDir "module_events.json")
                )) {
                    if (Test-Path $alt) { Copy-Item $alt $mcf -Force; break }
                }
            }
            if (Test-Path $errF) {
                try {
                    $stderrTail = ((Get-Content $errF -Raw -ErrorAction SilentlyContinue) + "")
                    if ($stderrTail.Length -gt 240) { $stderrTail = $stderrTail.Substring(0, 240) }
                    $stderrTail = ($stderrTail -replace '[\r\n]+', ' ').Trim()
                } catch { $stderrTail = "" }
            }
            Remove-Item $outF, $errF -Force -ErrorAction SilentlyContinue
            $c = Read-Counters $mcf
            $ad_s = Flag ($c.ad_init + $c.ad_san)
            $ad_t = Flag $c.ad_san
            $ad_m = 0
            if ($c.ad_san -gt 0 -and $c.ad_bd_after -eq 0) { $ad_m = 1 }
            $pe_s = Flag ($c.pe_calls + $c.pe_exam + $c.pe_mod_exam)
            $pe_t = Flag ($c.pe_filt + $c.pe_mod_filt)
            $env_s = Flag $c.env_exam
            $env_t = Flag $c.env_found
            $env_m = Flag $c.env_san
            $mc_s = Flag $c.mc_int
            $mc_t = Flag $c.mc_match
            $mc_m = Flag $c.mc_mod
            $sk_s = Flag ($c.sk_sleep + $c.sk_time)
            $sk_t = Flag $c.sk_corr
            $any_s = 0; if (($ad_s + $pe_s + $env_s + $mc_s + $sk_s) -gt 0) { $any_s = 1 }
            $any_t = 0; if (($ad_t + $pe_t + $env_t + $mc_t + $sk_t) -gt 0) { $any_t = 1 }
            $any_m = 0; if (($ad_m + $pe_t + $env_m + $mc_m + $sk_t) -gt 0) { $any_m = 1 }
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
                counters_json_ok = $c.json_ok
                surface_observed = $any_s
                countermeasure_triggered = $any_t
                result_modified = $any_m
                ad_surface = $ad_s; ad_triggered = $ad_t; ad_modified = $ad_m
                pe_surface = $pe_s; pe_triggered = $pe_t; pe_modified = $pe_t
                env_surface = $env_s; env_triggered = $env_t; env_modified = $env_m
                mc_surface = $mc_s; mc_triggered = $mc_t; mc_modified = $mc_m
                sk_surface = $sk_s; sk_triggered = $sk_t; sk_modified = $sk_t
                pe_calls = $c.pe_calls; pe_filtered = $c.pe_filt
                env_found = $c.env_found; env_sanitized = $c.env_san
                mc_intercepted = $c.mc_int; mc_matched = $c.mc_match
                sk_sleep = $c.sk_sleep; sk_corrections = $c.sk_corr
                ad_sanitizations = $c.ad_san
                pin_stderr = $stderrTail
            }
            [void]$rows.Add($row)
            $done[$k] = $true
            Save-Csv $rows $csvPath
            Write-Host ("  [{0}/{1}] {2} json={3} surf={4} trig={5} pe_filt={6} env={7} mc={8} exit={9}" -f `
                $n, $planned, $runId, $c.json_ok, $any_s, $any_t, $c.pe_filt, $c.env_san, $c.mc_mod, $code)
            if ($c.json_ok -eq 0 -and $stderrTail) {
                Write-Host ("           pin_err: {0}" -f $stderrTail)
            }
        }
    }
}

Write-Host ""
Write-Host "Etapa 5 done (or paused). Copy back:"
Write-Host "  $csvPath"
Write-Host "  $jsonDir"
Write-Host ("Rows: {0}" -f $rows.Count)
