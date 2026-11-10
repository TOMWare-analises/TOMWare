# Shared functions for TOMWare benchmark (Phase 4)

function Get-TomwareRepoRoot {
    param([string]$StartPath = $PSScriptRoot)
    $root = Resolve-Path (Join-Path $StartPath "..")
    return $root.Path
}

function Get-TomwareManifest {
    param([string]$ManifestPath)
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }
    return Get-Content $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-SamplePath {
    param(
        [string]$SamplesDir,
        [string]$Sha256
    )

    $candidates = @(
        (Join-Path $SamplesDir "$Sha256.exe"),
        (Join-Path $SamplesDir $Sha256),
        (Join-Path $SamplesDir "$($Sha256.ToUpper()).exe"),
        (Join-Path $SamplesDir "$($Sha256.ToLower()).exe")
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) { return (Resolve-Path $path).Path }
    }

    $found = Get-ChildItem -Path $SamplesDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq "$Sha256.exe" -or $_.BaseName -ieq $Sha256 } |
        Select-Object -First 1

    if ($found) { return $found.FullName }
    return $null
}

function Get-ExecutionOutcome {
    param(
        [int]$ExitCode,
        [double]$Seconds,
        [bool]$TimedOut,
        [double]$MinRuntimeSeconds = 2.0
    )

    if ($TimedOut) { return "timeout" }
    if ($ExitCode -lt 0) { return "error" }
    if ($Seconds -lt $MinRuntimeSeconds -and $ExitCode -ne 0) { return "early_exit" }
    if ($Seconds -ge $MinRuntimeSeconds -or $ExitCode -eq 0) { return "complete" }
    return "partial"
}

function Get-TomwareResourceSnapshot {
    param(
        [int]$RootProcessId,
        [string]$SamplePath,
        [datetime]$StartedAt,
        [hashtable]$CpuSecondsByPid
    )

    $sampleProcessName = [System.IO.Path]::GetFileNameWithoutExtension($SamplePath)
    $processNames = @($sampleProcessName, "pin", "pinbin") | Select-Object -Unique
    $workingSetBytes = [long]0
    $privateBytes = [long]0
    $processCount = 0

    foreach ($name in $processNames) {
        $processes = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        foreach ($process in $processes) {
            try {
                if ($process.Id -ne $RootProcessId -and $process.StartTime -lt $StartedAt.AddSeconds(-2)) {
                    continue
                }

                $process.Refresh()
                $cpuSeconds = [double]$process.CPU
                if (-not $CpuSecondsByPid.ContainsKey($process.Id) -or
                    $cpuSeconds -gt [double]$CpuSecondsByPid[$process.Id]) {
                    $CpuSecondsByPid[$process.Id] = $cpuSeconds
                }
                $workingSetBytes += [long]$process.WorkingSet64
                $privateBytes += [long]$process.PrivateMemorySize64
                $processCount++
            }
            catch {
                # The process may exit between Get-Process and Refresh.
            }
        }
    }

    return [PSCustomObject]@{
        ProcessCount      = $processCount
        WorkingSetBytes   = $workingSetBytes
        PrivateBytes      = $privateBytes
    }
}

function Stop-TomwareProcessTree {
    param(
        [int]$ProcessId = 0,
        [string]$SamplePath = ""
    )
    # taskkill writes "not found" to stderr; with $ErrorActionPreference=Stop that aborts the campaign
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        if ($ProcessId -gt 0) {
            cmd.exe /c "taskkill /PID $ProcessId /T /F >nul 2>&1" | Out-Null
            Start-Sleep -Milliseconds 300
            try {
                $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
                if ($p) { $p.Kill() }
            } catch {}
        }
        if ($SamplePath) {
            $base = [IO.Path]::GetFileNameWithoutExtension($SamplePath)
            # Prefer short name: full SHA256.exe often already exited / renamed
            if ($base -and $base.Length -ge 4) {
                $im = $base + ".exe"
                cmd.exe /c "taskkill /IM `"$im`" /T /F >nul 2>&1" | Out-Null
                if ($base.Length -gt 8) {
                    $short = $base.Substring(0, 8) + "*.exe"
                    # best-effort: kill by sha8 prefix via PowerShell
                    Get-Process -ErrorAction SilentlyContinue |
                        Where-Object { $_.ProcessName -like ($base.Substring(0, 8) + "*") } |
                        ForEach-Object {
                            try { $_.Kill() } catch {}
                        }
                }
            }
        }
        cmd.exe /c "taskkill /IM pin.exe /T /F >nul 2>&1" | Out-Null
        cmd.exe /c "taskkill /IM pinbin.exe /T /F >nul 2>&1" | Out-Null
    }
    finally {
        $ErrorActionPreference = $prev
    }
}

function Start-TomwareShutdownAbortWatchdog {
    <#
      Malware samples often call ExitWindows/InitiateSystemShutdown.
      Abort pending shutdowns every ~2s while the campaign runs.
    #>
    $script = @'
while ($true) {
  try { & shutdown.exe /a 2>$null | Out-Null } catch {}
  Start-Sleep -Seconds 2
}
'@
    $tmp = Join-Path $env:TEMP ("tomware_shutdown_abort_{0}.ps1" -f $PID)
    Set-Content -Path $tmp -Value $script -Encoding ASCII
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", $tmp
    ) -PassThru -WindowStyle Hidden
    return [PSCustomObject]@{ Pid = $proc.Id; ScriptPath = $tmp }
}

function Stop-TomwareShutdownAbortWatchdog {
    param($Handle)
    if (-not $Handle) { return }
    try {
        $p = Get-Process -Id $Handle.Pid -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Id $Handle.Pid -Force -ErrorAction SilentlyContinue }
    } catch {}
    if ($Handle.ScriptPath) {
        Remove-Item -LiteralPath $Handle.ScriptPath -Force -ErrorAction SilentlyContinue
    }
    try { & shutdown.exe /a 2>$null | Out-Null } catch {}
}

function Invoke-TomwarePinRun {
    param(
        [string]$PinExe,
        [string]$ToolDll,
        [string]$SamplePath,
        [string[]]$Knobs = @(),
        [switch]$FollowChild,
        [int]$TimeoutSeconds = 0,
        [string]$Scenario,
        [string]$ProgressLabel = ""
    )

    if (-not (Test-Path $PinExe)) { throw "pin.exe not found: $PinExe" }
    if (-not (Test-Path $ToolDll)) { throw "TOMWare.dll not found: $ToolDll" }
    if (-not (Test-Path $SamplePath)) { throw "Sample not found: $SamplePath" }

    $pinArgs = @()
    if ($FollowChild) { $pinArgs += "-follow_execv", "1" }
    $pinArgs += "-t", (Resolve-Path $ToolDll).Path
    if ($Knobs) { $pinArgs += $Knobs }
    $pinArgs += "--", (Resolve-Path $SamplePath).Path

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $stdout = ""
    $stderr = ""
    $exitCode = 1
    $startedAt = Get-Date
    $cpuSecondsByPid = @{}
    $resourceSamples = 0
    $workingSetSumBytes = [double]0
    $peakWorkingSetBytes = [long]0
    $peakPrivateBytes = [long]0
    $peakTrackedProcesses = 0

    if ($TimeoutSeconds -gt 0) {
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            $proc = Start-Process -FilePath $PinExe -ArgumentList $pinArgs `
                -PassThru -NoNewWindow -RedirectStandardOutput $outFile -RedirectStandardError $errFile

            $lastProgressAt = 0
            while (-not $proc.WaitForExit(1000)) {
                # Abort malware-initiated shutdown mid-run
                try { & shutdown.exe /a 2>$null | Out-Null } catch {}

                $snapshot = Get-TomwareResourceSnapshot -RootProcessId $proc.Id `
                    -SamplePath $SamplePath -StartedAt $startedAt -CpuSecondsByPid $cpuSecondsByPid
                if ($snapshot.ProcessCount -gt 0) {
                    $resourceSamples++
                    $workingSetSumBytes += $snapshot.WorkingSetBytes
                    $peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, $snapshot.WorkingSetBytes)
                    $peakPrivateBytes = [Math]::Max($peakPrivateBytes, $snapshot.PrivateBytes)
                    $peakTrackedProcesses = [Math]::Max($peakTrackedProcesses, $snapshot.ProcessCount)
                }

                $elapsedSeconds = [int][Math]::Floor($sw.Elapsed.TotalSeconds)
                if ($TimeoutSeconds -gt 0 -and $elapsedSeconds -ge $TimeoutSeconds) {
                    Stop-TomwareProcessTree -ProcessId $proc.Id -SamplePath $SamplePath
                    $timedOut = $true
                    $exitCode = -2
                    Write-Host ("    timeout: {0}s reached on {1}" -f $TimeoutSeconds, $(if ($ProgressLabel) { $ProgressLabel } else { $Scenario })) -ForegroundColor Yellow
                    break
                }

                if ($TimeoutSeconds -ge 60 -and ($elapsedSeconds -eq 5 -or ($elapsedSeconds - $lastProgressAt) -ge 30)) {
                    $label = if ($ProgressLabel) { $ProgressLabel } else { $Scenario }
                    Write-Host ("    waiting {0}: {1}s / {2}s" -f $label, $elapsedSeconds, $TimeoutSeconds) -ForegroundColor DarkGray
                    $lastProgressAt = $elapsedSeconds
                }
            }

            if (-not $timedOut) {
                $exitCode = $proc.ExitCode
            }
            else {
                Start-Sleep -Seconds 1
                Stop-TomwareProcessTree -ProcessId $proc.Id -SamplePath $SamplePath
            }

            $finalSnapshot = Get-TomwareResourceSnapshot -RootProcessId $proc.Id `
                -SamplePath $SamplePath -StartedAt $startedAt -CpuSecondsByPid $cpuSecondsByPid
            if ($finalSnapshot.ProcessCount -gt 0) {
                $resourceSamples++
                $workingSetSumBytes += $finalSnapshot.WorkingSetBytes
                $peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, $finalSnapshot.WorkingSetBytes)
                $peakPrivateBytes = [Math]::Max($peakPrivateBytes, $finalSnapshot.PrivateBytes)
                $peakTrackedProcesses = [Math]::Max($peakTrackedProcesses, $finalSnapshot.ProcessCount)
            }

            if (Test-Path $outFile) { $stdout = Get-Content $outFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue }
            if (Test-Path $errFile) { $stderr = Get-Content $errFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue }
        }
        finally {
            Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        $output = & $PinExe @pinArgs 2>&1
        $stdout = ($output | Out-String)
        $exitCode = $LASTEXITCODE
    }

    $sw.Stop()
    $cpuSeconds = [double]0
    foreach ($cpuValue in $cpuSecondsByPid.Values) {
        $cpuSeconds += [double]$cpuValue
    }
    $averageWorkingSetBytes = if ($resourceSamples -gt 0) {
        $workingSetSumBytes / $resourceSamples
    }
    else {
        0
    }
    $logicalProcessors = [Math]::Max(1, [Environment]::ProcessorCount)
    $cpuPercentOneCore = if ($sw.Elapsed.TotalSeconds -gt 0) {
        ($cpuSeconds / $sw.Elapsed.TotalSeconds) * 100.0
    }
    else {
        0
    }

    return [PSCustomObject]@{
        Scenario     = $Scenario
        ExitCode     = $exitCode
        Seconds      = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
        TimedOut     = $timedOut
        Outcome      = (Get-ExecutionOutcome -ExitCode $exitCode -Seconds $sw.Elapsed.TotalSeconds -TimedOut:$timedOut)
        Stdout       = $stdout
        Stderr       = $stderr
        Command      = "$PinExe $($pinArgs -join ' ')"
        ResourceMetrics = [PSCustomObject]@{
            Available              = ($resourceSamples -gt 0)
            SamplingIntervalMs     = 1000
            SampleCount            = $resourceSamples
            TrackedProcessPeak     = $peakTrackedProcesses
            CpuSeconds             = [Math]::Round($cpuSeconds, 3)
            CpuPercentOneCore      = [Math]::Round($cpuPercentOneCore, 2)
            CpuPercentTotalCapacity = [Math]::Round($cpuPercentOneCore / $logicalProcessors, 2)
            AverageWorkingSetMB    = [Math]::Round($averageWorkingSetBytes / 1MB, 3)
            PeakWorkingSetMB       = [Math]::Round($peakWorkingSetBytes / 1MB, 3)
            PeakPrivateMemoryMB    = [Math]::Round($peakPrivateBytes / 1MB, 3)
        }
    }
}

function Invoke-TomwareNativeRun {
    param(
        [string]$SamplePath,
        [int]$TimeoutSeconds = 0,
        [string]$Scenario = "native"
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $exitCode = 1
    $stdout = ""
    $stderr = ""

    if ($TimeoutSeconds -gt 0) {
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()
        try {
            # WorkingDirectory = sample folder so sidecar DLLs (if any) resolve
            $workDir = Split-Path -Parent $SamplePath
            $proc = Start-Process -FilePath $SamplePath -WorkingDirectory $workDir `
                -PassThru -NoNewWindow `
                -RedirectStandardOutput $outFile -RedirectStandardError $errFile
            if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                Stop-TomwareProcessTree -ProcessId $proc.Id -SamplePath $SamplePath
                $timedOut = $true
                $exitCode = -2
            }
            else {
                $exitCode = $proc.ExitCode
            }
            try { & shutdown.exe /a 2>$null | Out-Null } catch {}
            if (Test-Path $outFile) { $stdout = Get-Content $outFile -Raw -ErrorAction SilentlyContinue }
            if (Test-Path $errFile) { $stderr = Get-Content $errFile -Raw -ErrorAction SilentlyContinue }
        }
        finally {
            Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Push-Location (Split-Path -Parent $SamplePath)
        try {
            & $SamplePath 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
    }

    $sw.Stop()
    return [PSCustomObject]@{
        Scenario = $Scenario
        ExitCode = $exitCode
        Seconds  = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
        TimedOut = $timedOut
        Outcome  = (Get-ExecutionOutcome -ExitCode $exitCode -Seconds $sw.Elapsed.TotalSeconds -TimedOut:$timedOut)
        Stdout   = $stdout
        Stderr   = $stderr
        Command  = $SamplePath
    }
}

function Compare-TomwareRuns {
    param(
        $BaselineRun,
        $StealthRun
    )

    $improved = $false
    $reason = "no improvement"

    if ($BaselineRun.Outcome -eq "early_exit" -and $StealthRun.Outcome -in @("complete", "partial", "timeout")) {
        $improved = $true
        $reason = "baseline early_exit -> stealth $($StealthRun.Outcome)"
    }
    elseif ($StealthRun.Seconds -gt ($BaselineRun.Seconds * 1.25) -and $BaselineRun.Outcome -ne "timeout") {
        $improved = $true
        $reason = "stealth ran longer (+$([Math]::Round($StealthRun.Seconds - $BaselineRun.Seconds, 1))s)"
    }
    elseif ($BaselineRun.ExitCode -ne 0 -and $StealthRun.ExitCode -eq 0) {
        $improved = $true
        $reason = "exit code improved"
    }

    return [PSCustomObject]@{
        Improved = $improved
        Reason   = $reason
        DeltaSec = [Math]::Round($StealthRun.Seconds - $BaselineRun.Seconds, 3)
    }
}

function Export-TomwareBenchmarkSummary {
    param(
        [array]$Rows,
        [string]$OutputDir,
        [hashtable]$Metadata = @{}
    )

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    $csvPath = Join-Path $OutputDir "summary.csv"
    $jsonPath = Join-Path $OutputDir "summary.json"
    $mdPath = Join-Path $OutputDir "summary.md"

    $Rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    $Rows | ConvertTo-Json -Depth 6 | Set-Content $jsonPath -Encoding UTF8

    $total = $Rows.Count
    $improved = ($Rows | Where-Object { $_.Improved -eq $true }).Count
    $withSample = ($Rows | Where-Object { $_.SampleFound -eq $true }).Count

    $md = @"
# TOMWare benchmark — summary

Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Metadata

| Field | Value |
|-------|-------|
| Samples in the manifest | $($Metadata.TotalManifest) |
| Samples found | $withSample |
| Scenarios per sample | $($Metadata.Scenarios) |
| Timeout (s) | $($Metadata.TimeoutSeconds) |

## Aggregated results

| Metric | Value |
|---------|-------|
| Result rows | $total |
| Stealth vs baseline improvement | $improved |

## By sample

| SHA-256 | Scenario | Outcome | Seconds | Exit | Improved |
"@

    foreach ($row in $Rows) {
        $sha = if ($row.Sha256) { $row.Sha256.Substring(0, 16) + "..." } else { $row.TestId }
        $imp = if ($row.Improved) { "yes" } else { "-" }
        $md += "| $sha | $($row.Scenario) | $($row.Outcome) | $($row.Seconds) | $($row.ExitCode) | $imp |`n"
    }

    $md += @"

## Next steps

1. For samples with improvement, rerun with external tracing (if available).
2. Compare metrics with DBI-Log-Corpus.
3. Consolidate results in `summary.csv` and `summary.md` for the final report.

"@

    Set-Content -Path $mdPath -Value $md -Encoding UTF8

    return [PSCustomObject]@{
        Csv = $csvPath
        Json = $jsonPath
        Markdown = $mdPath
    }
}
