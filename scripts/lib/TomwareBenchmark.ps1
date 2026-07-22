# Funções compartilhadas para benchmark TOMWare (Fase 4)

function Get-TomwareRepoRoot {
    param([string]$StartPath = $PSScriptRoot)
    $root = Resolve-Path (Join-Path $StartPath "..")
    return $root.Path
}

function Get-TomwareManifest {
    param([string]$ManifestPath)
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifesto nao encontrado: $ManifestPath"
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
                # O processo pode encerrar entre Get-Process e Refresh.
            }
        }
    }

    return [PSCustomObject]@{
        ProcessCount      = $processCount
        WorkingSetBytes   = $workingSetBytes
        PrivateBytes      = $privateBytes
    }
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

    if (-not (Test-Path $PinExe)) { throw "pin.exe nao encontrado: $PinExe" }
    if (-not (Test-Path $ToolDll)) { throw "TOMWare.dll nao encontrada: $ToolDll" }
    if (-not (Test-Path $SamplePath)) { throw "Amostra nao encontrada: $SamplePath" }

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
                    $proc.Kill()
                    $timedOut = $true
                    $exitCode = -2
                    Write-Host ("    timeout: {0}s atingidos em {1}" -f $TimeoutSeconds, $(if ($ProgressLabel) { $ProgressLabel } else { $Scenario })) -ForegroundColor Yellow
                    break
                }

                if ($TimeoutSeconds -ge 60 -and ($elapsedSeconds -eq 5 -or ($elapsedSeconds - $lastProgressAt) -ge 30)) {
                    $label = if ($ProgressLabel) { $ProgressLabel } else { $Scenario }
                    Write-Host ("    aguardando {0}: {1}s / {2}s" -f $label, $elapsedSeconds, $TimeoutSeconds) -ForegroundColor DarkGray
                    $lastProgressAt = $elapsedSeconds
                }
            }

            if (-not $timedOut) {
                $exitCode = $proc.ExitCode
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

    if ($TimeoutSeconds -gt 0) {
        $proc = Start-Process -FilePath $SamplePath -PassThru -NoNewWindow
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $proc.Kill()
            $timedOut = $true
            $exitCode = -2
        }
        else { $exitCode = $proc.ExitCode }
    }
    else {
        & $SamplePath
        $exitCode = $LASTEXITCODE
    }

    $sw.Stop()
    return [PSCustomObject]@{
        Scenario = $Scenario
        ExitCode = $exitCode
        Seconds  = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
        TimedOut = $timedOut
        Outcome  = (Get-ExecutionOutcome -ExitCode $exitCode -Seconds $sw.Elapsed.TotalSeconds -TimedOut:$timedOut)
        Stdout   = ""
        Stderr   = ""
        Command  = $SamplePath
    }
}

function Compare-TomwareRuns {
    param(
        $BaselineRun,
        $StealthRun
    )

    $improved = $false
    $reason = "sem melhoria"

    if ($BaselineRun.Outcome -eq "early_exit" -and $StealthRun.Outcome -in @("complete", "partial", "timeout")) {
        $improved = $true
        $reason = "baseline early_exit -> stealth $($StealthRun.Outcome)"
    }
    elseif ($StealthRun.Seconds -gt ($BaselineRun.Seconds * 1.25) -and $BaselineRun.Outcome -ne "timeout") {
        $improved = $true
        $reason = "stealth executou mais tempo (+$([Math]::Round($StealthRun.Seconds - $BaselineRun.Seconds, 1))s)"
    }
    elseif ($BaselineRun.ExitCode -ne 0 -and $StealthRun.ExitCode -eq 0) {
        $improved = $true
        $reason = "exit code melhorou"
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
# Benchmark TOMWare — resumo

Gerado em: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Metadados

| Campo | Valor |
|-------|-------|
| Amostras no manifesto | $($Metadata.TotalManifest) |
| Amostras encontradas | $withSample |
| Cenarios por amostra | $($Metadata.Scenarios) |
| Timeout (s) | $($Metadata.TimeoutSeconds) |

## Resultados agregados

| Metrica | Valor |
|---------|-------|
| Linhas de resultado | $total |
| Melhoria stealth vs baseline | $improved |

## Por amostra

| SHA-256 | Cenario | Outcome | Segundos | Exit | Melhoria |
|---------|---------|---------|----------|------|----------|
"@

    foreach ($row in $Rows) {
        $sha = if ($row.Sha256) { $row.Sha256.Substring(0, 16) + "..." } else { $row.TestId }
        $imp = if ($row.Improved) { "sim" } else { "-" }
        $md += "| $sha | $($row.Scenario) | $($row.Outcome) | $($row.Seconds) | $($row.ExitCode) | $imp |`n"
    }

    $md += @"

## Proximos passos

1. Para amostras com melhoria, reexecutar com tracing externo (se disponivel).
2. Comparar metricas com DBI-Log-Corpus.
3. Consolidar resultados em `summary.csv` e `summary.md` para o relatorio final.

"@

    Set-Content -Path $mdPath -Value $md -Encoding UTF8

    return [PSCustomObject]@{
        Csv = $csvPath
        Json = $jsonPath
        Markdown = $mdPath
    }
}
