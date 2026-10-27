#Requires -Version 5.1
# Product oracles (waits, memcmp, -da smoke). Does NOT change SkewMask. Does NOT repeat N=30.
# Exclusive OutDir on first run. -Resume continues the same folder and skips
# completed ev_* (run_meta.json + run_id.txt + stdout.txt). Incomplete dirs are dropped.
# Do NOT revert tomware_go if you want to resume -- just power the guest back on.
param(
    [ValidateSet("Hash", "Waits", "Memcmp", "DaSmoke", "Pilot", "All")]
    [string]$Part = "Pilot",
    [string]$RepoRoot = "C:\TOMWare",
    [string]$CampaignId = "",
    [string]$OutDir = "",
    [int]$WaitN = 1,
    [int]$TimeoutSec = 90,
    [int]$DoTimeoutSec = 180,
    [switch]$Resume
)
$ErrorActionPreference = "Stop"
if (-not $CampaignId) { $CampaignId = "t2_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss") }
if (-not $OutDir) { $OutDir = "C:\TOMWare\oracle_$CampaignId" }
if (Test-Path $OutDir) {
    if (-not $Resume) {
        throw "OutDir already exists: $OutDir  Re-run with -Resume to continue this campaign (do not revert tomware_go)."
    }
    Write-Host "RESUME $OutDir"
} else {
    if ($Resume) { Write-Host "RESUME: folder missing, starting fresh $OutDir" }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$pin = Join-Path $RepoRoot "pin\pin.exe"
$dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
$empty = Join-Path $RepoRoot "x64\Release\EmptyPinTool.dll"
$here = if ($PSScriptRoot) { $PSScriptRoot } else { $OutDir }
Write-Host "campaign=$CampaignId out=$OutDir pin=3.28.98749 resume=$Resume"

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
    Get-Process -Name pin, pinbin, TestWaitModel, TestWaitModelV3, TestMemcmpVariants, TestMemcmpVariantsV3, TestAntiDebug, TestProcessEnum, TestGetEnvironments, TestMemoryScan, TestOverhead -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 400
}

function Ensure-CscExe {
    param([string]$CsPath, [string]$ExePath)
    if (Test-Path $ExePath) { Remove-Item $ExePath -Force }
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) { throw "csc.exe not found" }
    & $csc /nologo /out:$ExePath $CsPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ExePath)) { throw "compile failed $CsPath" }
    return $ExePath
}

function Invoke-Arm {
    param(
        [string]$Mode,
        [string]$Knobs,
        [string]$ExePath,
        [string]$KeepDir,
        [string]$RunId,
        [string[]]$ChildArgs = @(),
        [string]$WorkDir = $OutDir,
        [int]$ArmTimeoutSec = $TimeoutSec
    )
    if (-not $RunId) { throw "RunId required" }
    if (-not $KeepDir) { throw "KeepDir required" }
    New-Item -ItemType Directory -Force -Path $KeepDir | Out-Null
    Stop-Leftovers
    $outF = Join-Path $env:TEMP "jcvhtp_out_$RunId.txt"
    $errF = Join-Path $env:TEMP "jcvhtp_err_$RunId.txt"
    $file = $ExePath
    $args = @()
    if ($Mode -eq "empty") {
        $file = $pin
        $args = @("-t", $empty, "--", $ExePath) + $ChildArgs
    } elseif ($Mode -eq "tomware") {
        $file = $pin
        $args = @("-t", $dll)
        if ($Knobs) { $args += ($Knobs -split "\s+" | Where-Object { $_ }) }
        $args += @("--", $ExePath) + $ChildArgs
    } else {
        $args = $ChildArgs
    }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $obs = Start-Observed -FilePath $file -ArgumentList $args -WorkDir $WorkDir -OutF $outF -ErrF $errF
    $timedOut = $false
    if (-not $obs.Process.WaitForExit($ArmTimeoutSec * 1000)) {
        $timedOut = $true
        Stop-Process -Id $obs.Process.Id -Force -ErrorAction SilentlyContinue
        Stop-Leftovers
    }
    $code = Complete-Observed -Obs $obs
    $sw.Stop()
    if ($timedOut) { $code = -2 }
    $stdout = ""
    $stderr = ""
    if (Test-Path $outF) { $stdout = [IO.File]::ReadAllText($outF) }
    if (Test-Path $errF) { $stderr = [IO.File]::ReadAllText($errF) }
    Set-Content -Path (Join-Path $KeepDir "stdout.txt") -Value $stdout -Encoding UTF8
    Set-Content -Path (Join-Path $KeepDir "stderr.txt") -Value $stderr -Encoding UTF8
    Set-Content -Path (Join-Path $KeepDir "run_id.txt") -Value $RunId -Encoding ASCII
    $dllHash = if (Test-Path $dll) { (Get-FileHash $dll -Algorithm SHA256).Hash } else { "" }
    Set-Content -Path (Join-Path $KeepDir "run_meta.json") -Encoding UTF8 -Value (@{
        run_id = $RunId
        campaign_id = $CampaignId
        pin_version = "3.28.98749"
        snapshot = "tomware_go"
        dll_sha256 = $dllHash
        mode = $Mode
        knobs = $Knobs
        exe = $ExePath
        exit_code = $code
        timed_out = $timedOut
        duration_ms = [int]$sw.Elapsed.TotalMilliseconds
        timeout_sec = $ArmTimeoutSec
    } | ConvertTo-Json)
    Remove-Item $outF, $errF -Force -ErrorAction SilentlyContinue
    return [PSCustomObject]@{
        exit_code = $code
        timed_out = $timedOut
        duration_ms = [int]$sw.Elapsed.TotalMilliseconds
        excerpt = (($stdout -split "`r?`n" | Select-Object -First 20) -join " | ")
        stdout = $stdout
        stderr = $stderr
        run_id = $RunId
    }
}

function Write-Row($path, $row) {
    $exists = Test-Path $path
    $row | Export-Csv -Path $path -NoTypeInformation -Append:($exists) -Encoding UTF8
}

function Write-Sums {
    $sum = Join-Path $OutDir "SHA256SUMS.txt"
    $lines = @()
    Get-ChildItem $OutDir -Recurse -File | Where-Object { $_.Name -ne "SHA256SUMS.txt" } | Sort-Object FullName | ForEach-Object {
        $rel = $_.FullName.Substring($OutDir.Length).TrimStart("\", "/")
        $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
        $lines += "$h  $rel"
    }
    Set-Content -Path $sum -Value $lines -Encoding ASCII
    Write-Host "SHA256SUMS.txt n=$($lines.Count)"
}

function Disable-GuestSleep {
    try {
        powercfg /change standby-timeout-ac 0 | Out-Null
        powercfg /change standby-timeout-dc 0 | Out-Null
        powercfg /change hibernate-timeout-ac 0 | Out-Null
        powercfg /change hibernate-timeout-dc 0 | Out-Null
        powercfg /hibernate off | Out-Null
        Write-Host "guest sleep/hibernate off"
    } catch {
        Write-Host "powercfg skip: $_"
    }
}

function Test-KeepComplete([string]$dir) {
    if (-not $dir -or -not (Test-Path $dir)) { return $false }
    foreach ($n in @("run_meta.json", "run_id.txt", "stdout.txt")) {
        if (-not (Test-Path (Join-Path $dir $n))) { return $false }
    }
    return $true
}

function Find-CompleteKeep {
    param([string]$Filter)
    $dirs = @(Get-ChildItem $OutDir -Directory -Filter $Filter -ErrorAction SilentlyContinue)
    $hit = $null
    foreach ($d in $dirs) {
        if (Test-KeepComplete $d.FullName) { $hit = $d.FullName; continue }
        Write-Host "  drop incomplete $($d.Name)"
        Remove-Item $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $hit
}

function Write-ProgressNote([string]$msg) {
    $line = "{0}  {1}" -f (Get-Date).ToUniversalTime().ToString("o"), $msg
    Add-Content -Path (Join-Path $OutDir "PROGRESS.txt") -Value $line -Encoding ASCII
    Write-Host $line
}

function Read-Meta([string]$dir) {
    return (Get-Content (Join-Path $dir "run_meta.json") -Raw | ConvertFrom-Json)
}

function Excerpt-Stdout([string]$dir) {
    $p = Join-Path $dir "stdout.txt"
    if (-not (Test-Path $p)) { return "" }
    return ((Get-Content $p | Select-Object -First 20) -join " | ")
}

function Invoke-Hash {
    $bid = Join-Path $OutDir "build_id.json"
    if ($Resume -and (Test-Path $bid)) {
        Write-ProgressNote "SKIP Hash (build_id.json exists)"
        return
    }
    $stamp = (Get-Date).ToUniversalTime().ToString("o")
    $dllHash = (Get-FileHash $dll -Algorithm SHA256).Hash
    $pinHash = if (Test-Path $pin) { (Get-FileHash $pin -Algorithm SHA256).Hash } else { "" }
    $emptyHash = if (Test-Path $empty) { (Get-FileHash $empty -Algorithm SHA256).Hash } else { "MISSING" }
    $obj = [ordered]@{
        campaign = $CampaignId
        pin_version = "3.28.98749"
        snapshot = "tomware_go"
        collected_utc = $stamp
        pin_path = $pin
        dll_path = $dll
        dll_sha256 = $dllHash
        dll_prefix8 = $dllHash.Substring(0, 8)
        pin_sha256 = $pinHash
        empty_pintool_sha256 = $emptyHash
        note = "Identify by DLL SHA-256. Do not cite git 3040df7. Do not replace N=30."
    }
    Set-Content -Path (Join-Path $OutDir "build_id.json") -Value ($obj | ConvertTo-Json) -Encoding UTF8
    Write-Host "DLL SHA-256: $dllHash"
    if (-not $dllHash.StartsWith("4BBC6270")) {
        Write-Host "WARNING: DLL prefix is not 4BBC6270. Label this build separately."
    }
}

function Invoke-Waits {
    $waitCs = Join-Path $here "TestWaitModel.cs"
    $waitExe = Join-Path $OutDir "TestWaitModel.exe"
    Ensure-CscExe -CsPath $waitCs -ExePath $waitExe | Out-Null
    $wcsv = Join-Path $OutDir "waits_v3.csv"
    $arms = @(
        @{ name = "W3_NAT"; mode = "native"; knobs = "" },
        @{ name = "W3_EMPTY"; mode = "empty"; knobs = "" },
        @{ name = "W3_TMW0"; mode = "tomware"; knobs = "-q" },
        @{ name = "W3_DO"; mode = "tomware"; knobs = "-do -q" }
    )
    if (Test-Path $wcsv) { Remove-Item $wcsv -Force }
    foreach ($rep in 1..$WaitN) {
        foreach ($a in $arms) {
            $filter = "ev_{0}_{1:00}_*" -f $a.name, $rep
            $existing = Find-CompleteKeep -Filter $filter
            if ($existing) {
                $meta = Read-Meta $existing
                $rid = (Get-Content (Join-Path $existing "run_id.txt") -Raw).Trim()
                Write-Row $wcsv ([PSCustomObject]@{
                    run_id = $rid; campaign_id = $CampaignId
                    name = $a.name; knobs = $a.knobs; attempt = $rep
                    exit_code = $meta.exit_code; timed_out = $meta.timed_out
                    duration_ms = $meta.duration_ms; timeout_sec = $meta.timeout_sec
                    events_path = (Join-Path $existing "events.jsonl")
                    excerpt = (Excerpt-Stdout $existing)
                })
                Write-ProgressNote ("SKIP WAIT {0} rep={1} {2}" -f $a.name, $rep, (Split-Path $existing -Leaf))
                continue
            }
            $runId = [Guid]::NewGuid().ToString("N")
            $evDir = Join-Path $OutDir ("ev_{0}_{1:00}_{2}" -f $a.name, $rep, $runId.Substring(0, 8))
            $armTo = if ($a.knobs -match "-do") { $DoTimeoutSec } else { $TimeoutSec }
            Write-Host "WAIT $($a.name) rep=$rep run=$runId timeout=$armTo"
            $r = Invoke-Arm -Mode $a.mode -Knobs $a.knobs -ExePath $waitExe -KeepDir $evDir -RunId $runId -ChildArgs @($evDir, $runId) -ArmTimeoutSec $armTo
            Write-Row $wcsv ([PSCustomObject]@{
                run_id = $runId; campaign_id = $CampaignId
                name = $a.name; knobs = $a.knobs; attempt = $rep
                exit_code = $r.exit_code; timed_out = $r.timed_out
                duration_ms = $r.duration_ms; timeout_sec = $armTo
                events_path = (Join-Path $evDir "events.jsonl")
                excerpt = $r.excerpt
            })
            Write-ProgressNote ("DONE WAIT {0} rep={1} exit={2}" -f $a.name, $rep, $r.exit_code)
        }
    }
    Write-Host "waits v3 -> $wcsv"
}

function Invoke-Memcmp {
    $cs = Join-Path $here "TestMemcmpVariants.cs"
    $exe = Join-Path $OutDir "TestMemcmpVariants.exe"
    Ensure-CscExe -CsPath $cs -ExePath $exe | Out-Null
    $csv = Join-Path $OutDir "memcmp_variants_v3.csv"
    if (Test-Path $csv) { Remove-Item $csv -Force }
    foreach ($a in @(
        @{ name = "MC3_NAT"; mode = "native"; knobs = "" },
        @{ name = "MC3_TMW0"; mode = "tomware"; knobs = "-q" },
        @{ name = "MC3_DM"; mode = "tomware"; knobs = "-dm -q" },
        @{ name = "MC3_DA"; mode = "tomware"; knobs = "-da -q" }
    )) {
        $existing = Find-CompleteKeep -Filter ("ev_{0}_*" -f $a.name)
        if ($existing) {
            $meta = Read-Meta $existing
            $rid = (Get-Content (Join-Path $existing "run_id.txt") -Raw).Trim()
            Write-Row $csv ([PSCustomObject]@{
                run_id = $rid; campaign_id = $CampaignId
                name = $a.name; knobs = $a.knobs
                exit_code = $meta.exit_code; timed_out = $meta.timed_out
                duration_ms = $meta.duration_ms; excerpt = (Excerpt-Stdout $existing)
            })
            Write-ProgressNote ("SKIP MEM {0} {1}" -f $a.name, (Split-Path $existing -Leaf))
            continue
        }
        $runId = [Guid]::NewGuid().ToString("N")
        $evDir = Join-Path $OutDir ("ev_{0}_{1}" -f $a.name, $runId.Substring(0, 8))
        Write-Host "MEM $($a.name) run=$runId"
        $r = Invoke-Arm -Mode $a.mode -Knobs $a.knobs -ExePath $exe -KeepDir $evDir -RunId $runId
        Write-Row $csv ([PSCustomObject]@{
            run_id = $runId; campaign_id = $CampaignId
            name = $a.name; knobs = $a.knobs
            exit_code = $r.exit_code; timed_out = $r.timed_out
            duration_ms = $r.duration_ms; excerpt = $r.excerpt
        })
        Write-ProgressNote ("DONE MEM {0} exit={1}" -f $a.name, $r.exit_code)
    }
}

function Invoke-DaSmoke {
    $apps = Join-Path $RepoRoot "Resultados\Apps-Teste"
    $map = @(
        @{ name = "DA3_AD"; exe = "TestAntiDebug.exe"; knobs = "-gdb -da -q" },
        @{ name = "DA3_PE"; exe = "TestProcessEnum.exe"; knobs = "-da -q" },
        @{ name = "DA3_EV"; exe = "TestGetEnvironments.exe"; knobs = "-da -q" },
        @{ name = "DA3_MS"; exe = "TestMemoryScan.exe"; knobs = "-da -q" },
        @{ name = "DA3_SK"; exe = "TestOverhead.exe"; knobs = "-da -q" }
    )
    $csv = Join-Path $OutDir "da_oracles_v3.csv"
    if (Test-Path $csv) { Remove-Item $csv -Force }
    foreach ($m in $map) {
        $path = Join-Path $apps $m.exe
        if (-not (Test-Path $path)) {
            Write-Host "skip $($m.name) missing $path"
            continue
        }
        $existing = Find-CompleteKeep -Filter ("ev_{0}_*" -f $m.name)
        if ($existing) {
            $meta = Read-Meta $existing
            $rid = (Get-Content (Join-Path $existing "run_id.txt") -Raw).Trim()
            Write-Row $csv ([PSCustomObject]@{
                run_id = $rid; campaign_id = $CampaignId
                name = $m.name; knobs = $m.knobs; exe = $m.exe
                exit_code = $meta.exit_code; timed_out = $meta.timed_out
                duration_ms = $meta.duration_ms; excerpt = (Excerpt-Stdout $existing)
            })
            Write-ProgressNote ("SKIP DA {0} {1}" -f $m.name, (Split-Path $existing -Leaf))
            continue
        }
        $runId = [Guid]::NewGuid().ToString("N")
        $evDir = Join-Path $OutDir ("ev_{0}_{1}" -f $m.name, $runId.Substring(0, 8))
        Write-Host "DA $($m.name) run=$runId"
        $r = Invoke-Arm -Mode "tomware" -Knobs $m.knobs -ExePath $path -KeepDir $evDir -RunId $runId
        Write-Row $csv ([PSCustomObject]@{
            run_id = $runId; campaign_id = $CampaignId
            name = $m.name; knobs = $m.knobs; exe = $m.exe
            exit_code = $r.exit_code; timed_out = $r.timed_out
            duration_ms = $r.duration_ms; excerpt = $r.excerpt
        })
        Write-ProgressNote ("DONE DA {0} exit={1}" -f $m.name, $r.exit_code)
    }
}

Disable-GuestSleep
Write-Host "=== oracles Part=$Part campaign=$CampaignId (no SkewMask edit, no N=30) ==="
if ($Part -eq "Pilot") {
    $WaitN = 1
    Invoke-Hash
    Invoke-Memcmp
    Invoke-Waits
    Invoke-DaSmoke
} else {
    if ($Part -in @("Hash", "All")) { Invoke-Hash }
    if ($Part -in @("Memcmp", "All")) { Invoke-Memcmp }
    if ($Part -in @("Waits", "All")) { Invoke-Waits }
    if ($Part -in @("DaSmoke", "All")) { Invoke-DaSmoke }
}
Write-Sums
Write-ProgressNote "campaign complete Part=$Part"
Write-Host "done. Copy $OutDir back. If the VM dies mid-run: power on (do NOT revert tomware_go) and re-run the same command with -Resume."
