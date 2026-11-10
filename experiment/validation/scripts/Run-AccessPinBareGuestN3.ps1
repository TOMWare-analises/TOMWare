#Requires -Version 5.1
# Guest Pin-without-Pintool. N=3 on EACH guest pin.exe:
#   pin\pin.exe            expected 920A730A (documented campaign)
#   pin\intel64\bin\pin.exe expected FBA632E4 (r43c / host probe binary)
# Command: <pin> -- TestAntiDebug.exe
# Classification from raw files. Does not rewrite campaign.json. Not the 9000.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\pin_bare_guest_n3",
    [int]$TimeoutSec = 30,
    [int]$Reps = 3
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "Windows only." }
if (-not (Test-Path -LiteralPath "C:\TOMWare\pin")) {
    throw "Not the analysis guest (C:\TOMWare\pin missing)."
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

function Invoke-BareRep {
    param($PinPath, $Oracle, $RepDir, $TimeoutSec, $PinSha, $OracleSha, $PinVer, $ScriptSha, $Label, $Expected)
    New-Item -ItemType Directory -Force -Path $RepDir | Out-Null
    $cmdLine = '"{0}" -- "{1}"' -f $PinPath, $Oracle
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $PinPath
    $psi.Arguments = '-- "' + $Oracle + '"'
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
    Set-Content -Path (Join-Path $RepDir "stdout.txt") -Value $stdout -Encoding UTF8
    Set-Content -Path (Join-Path $RepDir "stderr.txt") -Value $stderr -Encoding UTF8
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
        pin_label = $Label
        expected_sha256 = $Expected
        rep = [int]($RepDir.Name -replace "rep_","")
        utc = $startedUtc
        command = $cmdLine
        pin_path = $PinPath
        pin_sha256 = $PinSha
        pin_sha256_matches_expected = ($PinSha -eq $Expected)
        pin_version_excerpt = $PinVer
        oracle_path = $Oracle
        oracle_sha256 = $OracleSha
        timeout_sec = $TimeoutSec
        timed_out = $timedOut
        exit_code = $code
        duration_ms = [int]$sw.Elapsed.TotalMilliseconds
        startserver_assert = [bool]$assert
        oracle_ok = [bool]$oracleOk
        rep_conclusion = $repConclusion
        script_sha256 = $ScriptSha
        not_a_claim = "not the 9000; classify from these files"
    }
    ($meta | ConvertTo-Json) | Set-Content -Path (Join-Path $RepDir "run_meta.json") -Encoding UTF8
    $meta.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } |
        Set-Content -Path (Join-Path $RepDir "verdict.txt") -Encoding UTF8
    Write-Host ("{0} rep {1} {2} exit={3} ms={4}" -f $Label, $meta.rep, $repConclusion, $code, $meta.duration_ms)
    return [pscustomobject]$meta
}

function Classify-Arm($rows, $expectedOk) {
    $nOk = @($rows | Where-Object { $_.rep_conclusion -eq "completed_ok" }).Count
    $nAssert = @($rows | Where-Object { $_.rep_conclusion -eq "startserver_assert" }).Count
    $hashOk = @($rows | Where-Object { $_.pin_sha256_matches_expected }).Count -eq $rows.Count
    if (-not $hashOk) { return @{ class = "inconclusive_pin_hash_mismatch"; n_ok = $nOk } }
    if ($nOk -eq $rows.Count) { return @{ class = "technically_valid_omitted_from_9000_by_design"; n_ok = $nOk } }
    if ($nOk -eq 0 -and $nAssert -eq $rows.Count) { return @{ class = "incompatible_reproduced_on_this_pin"; n_ok = $nOk } }
    return @{ class = "inconclusive_mixed_reps"; n_ok = $nOk }
}

$scriptPath = $MyInvocation.MyCommand.Path
$scriptSha = if ($scriptPath) { Get-Sha $scriptPath } else { "" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$oracleCandidates = @(
    (Join-Path $RepoRoot "experiment\apps\oracles\TestAntiDebug.exe"),
    (Join-Path $RepoRoot "oracles\TestAntiDebug.exe")
)
$oracle = $oracleCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $oracle) { throw "TestAntiDebug.exe missing" }
$oracle = (Resolve-Path -LiteralPath $oracle).Path
$oracleSha = Get-Sha $oracle

$arms = @(
    @{ label = "campaign_pin_pin.exe"; path = (Join-Path $RepoRoot "pin\pin.exe"); expected = "920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819" }
    @{ label = "intel64_bin_pin.exe"; path = (Join-Path $RepoRoot "pin\intel64\bin\pin.exe"); expected = "FBA632E40F00FEEC1FAA7BC1A3BF8CC9A551AB1F17ABA6B07D31C67E602A741A" }
)

$all = New-Object System.Collections.Generic.List[object]
$classLines = New-Object System.Collections.Generic.List[string]
$classLines.Add(("utc={0}" -f (Get-Date).ToUniversalTime().ToString("o")))
$classLines.Add(("computer={0}" -f $env:COMPUTERNAME))
$classLines.Add(("oracle_sha256={0}" -f $oracleSha))
$classLines.Add(("script_sha256={0}" -f $scriptSha))

foreach ($arm in $arms) {
    if (-not (Test-Path -LiteralPath $arm.path)) {
        $classLines.Add(("{0}=MISSING {1}" -f $arm.label, $arm.path))
        continue
    }
    $pin = (Resolve-Path -LiteralPath $arm.path).Path
    $pinSha = Get-Sha $pin
    $pinVer = Get-PinVersion $pin
    $armDir = Join-Path $OutDir $arm.label
    New-Item -ItemType Directory -Force -Path $armDir | Out-Null
    Set-Content -Path (Join-Path $armDir "pin_version.txt") -Value $pinVer -Encoding UTF8
    $armRows = New-Object System.Collections.Generic.List[object]
    1..$Reps | ForEach-Object {
        $repDir = Join-Path $armDir ("rep_{0}" -f $_)
        $row = Invoke-BareRep -PinPath $pin -Oracle $oracle -RepDir $repDir -TimeoutSec $TimeoutSec `
            -PinSha $pinSha -OracleSha $oracleSha -PinVer $pinVer -ScriptSha $scriptSha `
            -Label $arm.label -Expected $arm.expected
        $armRows.Add($row)
        $all.Add($row)
    }
    $cls = Classify-Arm $armRows $true
    $classLines.Add("")
    $classLines.Add(("arm={0}" -f $arm.label))
    $classLines.Add(("pin_path={0}" -f $pin))
    $classLines.Add(("pin_sha256={0}" -f $pinSha))
    $classLines.Add(("expected={0}" -f $arm.expected))
    $classLines.Add(("classification={0}" -f $cls.class))
    $classLines.Add(("n_ok={0}/{1}" -f $cls.n_ok, $armRows.Count))
}

$camp = $all | Where-Object { $_.pin_label -eq "campaign_pin_pin.exe" }
$intel = $all | Where-Object { $_.pin_label -eq "intel64_bin_pin.exe" }
$campCls = if ($camp) { (Classify-Arm $camp $true).class } else { "missing" }
$intelCls = if ($intel) { (Classify-Arm $intel $true).class } else { "missing" }

if ($campCls -eq "technically_valid_omitted_from_9000_by_design") {
    $overall = "campaign_pin_technically_valid_omitted_from_9000_by_design"
    $reading = "pin\pin.exe (920A730A) completed pin.exe -- TestAntiDebug.exe. PIN was omitted from the 9,000 by design. Not incompatible."
} elseif ($campCls -eq "incompatible_reproduced_on_this_pin") {
    $overall = "campaign_pin_incompatible"
    $reading = "StartServer/assert reproduced on documented campaign pin\pin.exe (920A730A)."
} elseif ($campCls -eq "missing") {
    $overall = "inconclusive_campaign_pin_missing"
    $reading = "pin\pin.exe missing on the guest. Incompatibility of the campaign pin is not confirmed."
} else {
    $overall = "inconclusive_campaign_pin"
    $reading = "Campaign pin\pin.exe did not produce a uniform completed_ok or uniform assert. Incompatibility not confirmed."
}
$classLines.Add("")
$classLines.Add(("overall={0}" -f $overall))
$classLines.Add(("intel64_arm={0}" -f $intelCls))
$classLines.Add($reading)
$classLines.Add("Do not rewrite campaign.json. identified=false. Not Arancino. Not the 9000.")

$all | Export-Csv -Path (Join-Path $OutDir "summary.csv") -NoTypeInformation -Encoding UTF8
Set-Content -Path (Join-Path $OutDir "classification.txt") -Value $classLines -Encoding UTF8
Write-Host ("OVERALL {0}" -f $overall)
Write-Host ("intel64 {0}" -f $intelCls)
Write-Host ("out {0}" -f $OutDir)
