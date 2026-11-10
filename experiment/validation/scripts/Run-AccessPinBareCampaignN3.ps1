#Requires -Version 5.1
# Guest Pin-without-Pintool. ONLY the campaign launcher.
# Command: C:\TOMWare\pin\pin.exe -- TestAntiDebug.exe
# Launcher SHA-256 must be 920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819
# N=3. Classify from raw files. Host StartServer is not incompatibility proof.
# Does not rewrite campaign.json. Not the 9000.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\pin_bare_guest_n3",
    [int]$TimeoutSec = 30,
    [int]$Reps = 3,
    [string]$ExpectedLauncherSha256 = "920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819",
    [string]$ExpectedOracleSha256 = "3B25069EEBC099593905F6075AF210E9DAE53AD405A5D98C3BB0DFCC0CE1CECD"
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "Windows only." }
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "pin\pin.exe"))) {
    throw "Not the analysis guest, or campaign launcher missing (C:\TOMWare\pin\pin.exe)."
}

function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-PinVersion([string]$PinPath) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $PinPath
        $psi.Arguments = "-version"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()
        $o = $p.StandardOutput.ReadToEndAsync()
        $e = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit(8000)) { try { $p.Kill() } catch {}; return "pin_-version_timeout" }
        $txt = ""
        try { if ($o.IsCompleted) { $txt = $o.Result } } catch {}
        if (-not $txt) { try { if ($e.IsCompleted) { $txt = $e.Result } } catch {} }
        return (($txt -split "`r?`n") | Select-Object -First 3) -join " | "
    } catch {
        return ("pin_version_error {0}" -f $_.Exception.Message)
    }
}

$scriptPath = $MyInvocation.MyCommand.Path
$scriptSha = if ($scriptPath) { Get-Sha $scriptPath } else { "" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$launcher = (Resolve-Path -LiteralPath (Join-Path $RepoRoot "pin\pin.exe")).Path
$launcherSha = Get-Sha $launcher
if ($launcherSha -ne $ExpectedLauncherSha256.ToUpperInvariant()) {
    throw ("pin\pin.exe SHA-256 {0} != 920A730A. Stop. Do not use intel64\bin\pin.exe or the host probe." -f $launcherSha)
}

$engine = $null
$engineSha = ""
foreach ($rel in @("pin\intel64\bin\pinbin.exe", "pin\intel64\bin\pin.exe")) {
    $cand = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $cand) {
        $engine = (Resolve-Path -LiteralPath $cand).Path
        $engineSha = Get-Sha $engine
        break
    }
}

$oracleCandidates = @(
    (Join-Path $RepoRoot "experiment\apps\oracles\TestAntiDebug.exe"),
    (Join-Path $RepoRoot "oracles\TestAntiDebug.exe")
)
$oracle = $oracleCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $oracle) { throw "TestAntiDebug.exe missing" }
$oracle = (Resolve-Path -LiteralPath $oracle).Path
$oracleSha = Get-Sha $oracle
$oracleMatch = ($oracleSha -eq $ExpectedOracleSha256.ToUpperInvariant())

$pinVer = Get-PinVersion $launcher
Set-Content -Path (Join-Path $OutDir "pin_version.txt") -Value $pinVer -Encoding UTF8

$all = New-Object System.Collections.Generic.List[object]
1..$Reps | ForEach-Object {
    $repDir = Join-Path $OutDir ("rep_{0}" -f $_)
    New-Item -ItemType Directory -Force -Path $repDir | Out-Null
    $cmdLine = '"{0}" -- "{1}"' -f $launcher, $oracle
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $launcher
    $psi.Arguments = '-- "' + $oracle + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $startedUtc = (Get-Date).ToUniversalTime().ToString("o")
    [void]$proc.Start()
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $exited = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $exited) {
        try { $proc.Kill() } catch {}
        Start-Sleep -Milliseconds 400
        cmd.exe /c "taskkill /IM pin.exe /T /F >nul 2>&1" | Out-Null
        cmd.exe /c "taskkill /IM pinbin.exe /T /F >nul 2>&1" | Out-Null
    }
    $sw.Stop()
    try { [void]$outTask.Wait(1500) } catch {}
    try { [void]$errTask.Wait(1500) } catch {}
    $stdout = ""; $stderr = ""
    try { if ($outTask.IsCompleted) { $stdout = $outTask.Result } } catch {}
    try { if ($errTask.IsCompleted) { $stderr = $errTask.Result } } catch {}
    Set-Content -Path (Join-Path $repDir "stdout.txt") -Value $stdout -Encoding UTF8
    Set-Content -Path (Join-Path $repDir "stderr.txt") -Value $stderr -Encoding UTF8
    $code = $null
    try { if ($proc.HasExited) { $code = $proc.ExitCode } } catch {}
    $timedOut = -not $exited
    $blob = "$stdout`n$stderr"
    $assert = ($blob -match "StartServer") -or ($blob -match "assertion failed")
    $oracleOk = ($stdout -match "OK") -or ($stdout -match "nenhuma anomalia")
    $completed = ($code -eq 0) -and (-not $timedOut) -and (-not $assert)
    $repConclusion = if ($completed) { "completed_ok" } elseif ($timedOut) { "timed_out" } elseif ($assert) { "startserver_assert" } else { "failed" }
    $meta = [ordered]@{
        campaign_id = "access_pin_bare_guest_n3"
        machine = "guest"
        snapshot = "tomware_go"
        script_rev = "pinbare_campaign_n3.1"
        rep = $_
        utc = $startedUtc
        command = $cmdLine
        pin_launcher_path = $launcher
        pin_launcher_sha256 = $launcherSha
        pin_launcher_matches_campaign = $true
        pin_engine_path = $engine
        pin_engine_sha256 = $engineSha
        pin_version_excerpt = $pinVer
        oracle_path = $oracle
        oracle_sha256 = $oracleSha
        oracle_sha256_matches_expected = $oracleMatch
        timeout_sec = $TimeoutSec
        timed_out = $timedOut
        exit_code = $code
        duration_ms = [int]$sw.Elapsed.TotalMilliseconds
        startserver_assert = [bool]$assert
        oracle_ok = [bool]$oracleOk
        rep_conclusion = $repConclusion
        script_sha256 = $scriptSha
        not_a_claim = "not the 9000; host StartServer is not this result; classify from these files"
    }
    ($meta | ConvertTo-Json) | Set-Content -Path (Join-Path $repDir "run_meta.json") -Encoding UTF8
    $meta.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } |
        Set-Content -Path (Join-Path $repDir "verdict.txt") -Encoding UTF8
    $all.Add([pscustomobject]$meta)
    Write-Host ("rep {0} {1} exit={2} ms={3}" -f $_, $repConclusion, $code, $meta.duration_ms)
}

$nOk = @($all | Where-Object { $_.rep_conclusion -eq "completed_ok" }).Count
$nAssert = @($all | Where-Object { $_.rep_conclusion -eq "startserver_assert" }).Count
if ($nOk -eq $all.Count) {
    $overall = "campaign_pin_technically_valid_omitted_from_9000_by_design"
    $reading = "pin\pin.exe (920A730A) completed pin.exe -- TestAntiDebug.exe on N=3. PIN was omitted from the 9,000 by design. Not incompatible."
} elseif ($nAssert -eq $all.Count) {
    $overall = "campaign_pin_incompatible_reproduced"
    $reading = "StartServer/assert reproduced on documented campaign pin\pin.exe (920A730A), N=3."
} else {
    $overall = "inconclusive_mixed_reps"
    $reading = "Campaign pin\pin.exe N=3 was not uniformly completed_ok or uniformly assert. Incompatibility not confirmed."
}

$classLines = @(
    ("utc={0}" -f (Get-Date).ToUniversalTime().ToString("o")),
    ("computer={0}" -f $env:COMPUTERNAME),
    ("command={0} -- {1}" -f $launcher, $oracle),
    ("pin_launcher_sha256={0}" -f $launcherSha),
    ("pin_engine_path={0}" -f $engine),
    ("pin_engine_sha256={0}" -f $engineSha),
    ("oracle_sha256={0}" -f $oracleSha),
    ("pin_version={0}" -f $pinVer),
    ("script_sha256={0}" -f $scriptSha),
    ("n_ok={0}/{1}" -f $nOk, $all.Count),
    ("n_assert={0}/{1}" -f $nAssert, $all.Count),
    ("overall={0}" -f $overall),
    $reading,
    "Host StartServer / FBA632E4 is not this classification.",
    "Do not rewrite campaign.json. identified=false. Not Arancino. Not the 9000."
)
$all | Export-Csv -Path (Join-Path $OutDir "summary.csv") -NoTypeInformation -Encoding UTF8
Set-Content -Path (Join-Path $OutDir "classification.txt") -Value $classLines -Encoding UTF8
Write-Host ("OVERALL {0}" -f $overall)
Write-Host ("out {0}" -f $OutDir)
