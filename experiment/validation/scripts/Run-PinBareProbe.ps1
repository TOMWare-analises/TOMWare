#Requires -Version 5.1
# Pin-without-Pintool probe. One run. Does not rerun the 9,000.
# Guest: C:\TOMWare. Host allowed only with -AllowHost (label the machine).
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OracleRel = "Resultados\Apps-Teste\TestAntiDebug.exe",
    [string]$OutDir = "",
    [int]$TimeoutSec = 30,
    [switch]$AllowHost
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "Windows only." }
$onGuest = Test-Path -LiteralPath "C:\TOMWare\pin\intel64\bin\pin.exe"
if (-not $onGuest -and -not $AllowHost) {
    throw "Not the analysis guest. Pass -AllowHost to record a host probe (separate from the 9,000)."
}
if (-not $OutDir) {
    $OutDir = if ($onGuest) { "C:\TOMWare\pin_bare_probe" } else {
        Join-Path $RepoRoot "experiment\results\oracles\guest\pin_bare_probe_host"
    }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$pinCandidates = @(
    (Join-Path $RepoRoot "pin\intel64\bin\pin.exe"),
    (Join-Path $RepoRoot "pin\pin.exe"),
    "C:\TOMWare\pin\intel64\bin\pin.exe"
)
$pin = $pinCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $pin) { throw "pin.exe not found" }
$oracle = Join-Path $RepoRoot $OracleRel
if (-not (Test-Path -LiteralPath $oracle)) {
    $oracle = Join-Path $RepoRoot "oracles\TestAntiDebug.exe"
}
if (-not (Test-Path -LiteralPath $oracle)) { throw "oracle missing: $OracleRel" }

$pin = (Resolve-Path -LiteralPath $pin).Path
$oracle = (Resolve-Path -LiteralPath $oracle).Path
$pinSha = (Get-FileHash -LiteralPath $pin -Algorithm SHA256).Hash.ToUpperInvariant()
$exeSha = (Get-FileHash -LiteralPath $oracle -Algorithm SHA256).Hash.ToUpperInvariant()
$stdoutPath = Join-Path $OutDir "stdout.txt"
$stderrPath = Join-Path $OutDir "stderr.txt"
$cmdLine = '"{0}" -- "{1}"' -f $pin, $oracle

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $pin
$psi.Arguments = '-- "' + $oracle + '"'
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$sw = [Diagnostics.Stopwatch]::StartNew()
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
$stdout = ""
$stderr = ""
try { if ($outTask.IsCompleted) { $stdout = $outTask.Result } } catch {}
try { if ($errTask.IsCompleted) { $stderr = $errTask.Result } } catch {}
Set-Content -Path $stdoutPath -Value $stdout -Encoding UTF8
Set-Content -Path $stderrPath -Value $stderr -Encoding UTF8
$code = $null
try { if ($proc.HasExited) { $code = $proc.ExitCode } } catch {}
$timedOut = -not $exited
$assert = ($stderr -match "StartServer") -or ($stderr -match "assertion failed")
$oracleOk = ($stdout -match "OK") -and ($code -eq 0) -and (-not $timedOut) -and (-not $assert)
if ($oracleOk) { $verdict = "supported" } else { $verdict = "not_supported_by_engine" }

$meta = [ordered]@{
    campaign_id = if ($onGuest) { "access_pin_bare_guest" } else { "access_pin_bare_host" }
    machine = if ($onGuest) { "guest" } else { "host" }
    command = $cmdLine
    pin_path = $pin
    pin_sha256 = $pinSha
    oracle_path = $oracle
    oracle_sha256 = $exeSha
    timeout_sec = $TimeoutSec
    timed_out = $timedOut
    exit_code = $code
    duration_ms = [int]$sw.Elapsed.TotalMilliseconds
    stdout_bytes = [Text.Encoding]::UTF8.GetByteCount($stdout)
    stderr_bytes = [Text.Encoding]::UTF8.GetByteCount($stderr)
    startserver_assert = [bool]$assert
    conclusion = $verdict
    not_a_claim = "host probe is not the 9000; guest campaign.json omitted PIN"
}
($meta | ConvertTo-Json) | Set-Content -Path (Join-Path $OutDir "run_meta.json") -Encoding UTF8
$meta.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } |
    Set-Content -Path (Join-Path $OutDir "verdict.txt") -Encoding UTF8
Write-Host ("conclusion {0} exit={1} duration_ms={2}" -f $verdict, $code, $meta.duration_ms)
Write-Host ("out {0}" -f $OutDir)
