#Requires -Version 5.1
<#
.SYNOPSIS
  Executa uma corrida experimental individual de forma auditavel e com gravacao atomica (TOMWare.M).
#>
param(
    [Parameter(Mandatory = $true)]
    [psobject]$PlanRow,
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$CampaignDir,
    [psobject]$Config = $null,
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# Carregar coletor de processo
. (Join-Path $RepoRoot "experiment/scripts/collectors/ProcessCollector.ps1")

# Collector v2.1: never treat a null ExitCode as a crash.
# PowerShell 5.1 + Start-Process -RedirectStandard* often leaves ExitCode
# unpopulated until Refresh/HasExited. $null -lt 0 is True, which used to
# mark 6517 corpus runs as exception_crash with exception_code "0x".
function Get-SafeProcessExitCode {
    param($Process)
    if ($null -eq $Process) { return $null }
    try {
        $Process.Refresh()
        if (-not $Process.HasExited) { return $null }
        # .NET: after WaitForExit(ms) with redirected streams, a second
        # WaitForExit() with no timeout flushes async buffers and fills ExitCode.
        $Process.WaitForExit()
        return $Process.ExitCode
    } catch {
        return $null
    }
}

$runId = $PlanRow.run_id
$campaignId = $PlanRow.campaign_id
$sampleId = $PlanRow.sample_id
$expectedSha256 = ($PlanRow.sha256).ToUpper()
$cond = $PlanRow.condition
$prof = $PlanRow.execution_profile
$timeoutSec = [int]$PlanRow.timeout_seconds
$windowSec = [int]$PlanRow.window_seconds
$samplingIntervalMs = if ($Config -and $Config.sampling) { [int]$Config.sampling.resource_interval_ms } else { 200 }

# Diretorios de saida
$runsDir = Join-Path $CampaignDir "raw/runs"
$resourcesDir = Join-Path $CampaignDir "raw/resources"
$stdoutDir = Join-Path $CampaignDir "raw/stdout"
$stderrDir = Join-Path $CampaignDir "raw/stderr"

foreach ($d in @($runsDir, $resourcesDir, $stdoutDir, $stderrDir)) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}

$finalJsonPath = Join-Path $runsDir "$runId.json"
$tempJsonPath = Join-Path $runsDir "$runId.json.tmp"
$stdoutPath = Join-Path $stdoutDir "$runId.stdout.txt"
$stderrPath = Join-Path $stderrDir "$runId.stderr.txt"
$timeSeriesPath = Join-Path $resourcesDir "$($runId)_resources.csv"

# Idempotencia segura: nao sobrescrever silenciosamente execucao concluida
if (Test-Path $finalJsonPath) {
    Write-Host "    [SKIP] Execucao ja concluida anteriormente: $runId" -ForegroundColor DarkGray
    return [PSCustomObject]@{
        RunId  = $runId
        Status = "already_completed"
        Json   = $finalJsonPath
    }
}

# 1. Localizar binario da amostra
$samplePath = $null
$candidateDirs = @(
    (Join-Path $RepoRoot "samples/benign"),
    (Join-Path $RepoRoot "samples/infected"),
    (Join-Path $RepoRoot "malwares/benign"),
    (Join-Path $RepoRoot "malwares/infected"),
    (Join-Path $RepoRoot "Resultados/Apps-Teste")
)

foreach ($d in $candidateDirs) {
    if (Test-Path $d) {
        $c1 = Join-Path $d "$expectedSha256.exe"
        $c2 = Join-Path $d "$($expectedSha256.ToLower()).exe"
        $c3 = Join-Path $d "$expectedSha256"
        if (Test-Path $c1) { $samplePath = (Resolve-Path $c1).Path; break }
        if (Test-Path $c2) { $samplePath = (Resolve-Path $c2).Path; break }
        if (Test-Path $c3) { $samplePath = (Resolve-Path $c3).Path; break }
    }
}

if (-not $samplePath) {
    # Procura recursiva por SHA ou nome de oracle
    $found = Get-ChildItem -Path $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -ieq $expectedSha256 -or $_.Name -ieq "$expectedSha256.exe" -or $_.BaseName -ieq $sampleId } |
        Select-Object -First 1
    if ($found) { $samplePath = $found.FullName }
}

# 2. Verificacao do hash antes da execucao
$hashValid = $false
$actualSha256 = ""
if ($samplePath -and (Test-Path $samplePath)) {
    $actualSha256 = (Get-FileHash -Path $samplePath -Algorithm SHA256).Hash.ToUpper()
    if ($actualSha256 -eq $expectedSha256 -or $samplePath -like "*Apps-Teste*") {
        $hashValid = $true
    }
}

# 3. Limpeza pre-execucao de processos residuais
Stop-ProcessTreeGuaranteed -SamplePath $samplePath

# Ferramentas auxiliares
$pinExe = Resolve-Path (Join-Path $RepoRoot "pin/pin.exe") -ErrorAction SilentlyContinue
$tomwareDll = Resolve-Path (Join-Path $RepoRoot "x64/Release/TOMWare.dll") -ErrorAction SilentlyContinue
$emptyToolDll = Resolve-Path (Join-Path $RepoRoot "x64/Release/EmptyPinTool.dll") -ErrorAction SilentlyContinue

$startUtc = (Get-Date).ToUniversalTime().ToString("o")

if ($DryRun) {
    Write-Host "    [DRY-RUN] Planejado: $runId ($cond) -> $samplePath" -ForegroundColor Yellow
    return [PSCustomObject]@{
        RunId   = $runId
        Status  = "dry_run"
        Command = "DRY-RUN"
    }
}

# Tratamento se a amostra nao existir ou o hash for invalido
if (-not $samplePath -or -not (Test-Path $samplePath) -or -not $hashValid) {
    $endUtc = (Get-Date).ToUniversalTime().ToString("o")
    $missingReason = if (-not $samplePath) { "file_not_found" } else { "sha256_mismatch" }

    $failedRecord = [ordered]@{
        schema_version = 1
        identification = [ordered]@{
            campaign_id            = $campaignId
            run_id                 = $runId
            sample_id              = $sampleId
            sha256                 = $PlanRow.sha256
            block_id               = $PlanRow.block_id
            repetition             = [int]$PlanRow.repetition
            condition              = $cond
            modules_enabled        = @()
            run_order              = [int]$PlanRow.order_in_block
            random_seed            = [int]$PlanRow.random_seed
            host_id                = $env:COMPUTERNAME
            vm_id                  = ""
            snapshot_id            = ""
            restore_completed      = $false
            start_timestamp_utc    = $startUtc
            end_timestamp_utc      = $endUtc
            monotonic_duration_ms  = 0
            configuration_hash     = ""
        }
        operational_outcome = [ordered]@{
            launch_success              = $false
            pid                         = 0
            parent_pid                  = $PID
            natural_completion          = $false
            timeout                     = $false
            still_active_at_window_end  = $false
            controlled_termination      = $false
            crash                       = $false
            exception_code              = $null
            exit_code                   = $null
            termination_reason          = "launch_failed"
            observation_duration_ms     = 0
            time_to_first_activity_ms   = $null
            collector_failure           = $false
            missing_reason              = $missingReason
        }
        timing_and_cpu = [ordered]@{
            wall_clock_ms      = 0
            cpu_user_ms        = 0
            cpu_kernel_ms      = 0
            cpu_total_ms       = 0
            cpu_percent_mean   = 0
            cpu_percent_max    = 0
            logical_processors = [Environment]::ProcessorCount
        }
        memory = [ordered]@{
            peak_working_set_bytes    = 0
            average_working_set_bytes = 0
            peak_private_bytes        = 0
            average_private_bytes     = 0
            sample_count              = 0
        }
        io = [ordered]@{
            bytes_read       = 0
            bytes_written    = 0
            read_operations  = 0
            write_operations = 0
            files_created    = @()
            files_modified   = @()
            files_deleted    = @()
        }
        processes_threads_modules = [ordered]@{
            peak_tracked_processes = 0
            peak_tracked_threads   = 0
            child_pids             = @()
            loaded_modules_count   = 0
        }
        behavioral_fidelity = [ordered]@{
            stdout_sha256 = ""
            stderr_sha256 = ""
            stdout_bytes  = 0
            stderr_bytes  = 0
        }
        artifacts = [ordered]@{
            raw_record_json_path      = $finalJsonPath
            stdout_path               = $stdoutPath
            stderr_path               = $stderrPath
            resource_time_series_path = $null
        }
    }

    $failedRecord | ConvertTo-Json -Depth 6 | Set-Content -Path $tempJsonPath -Encoding UTF8
    Move-Item -Path $tempJsonPath -Destination $finalJsonPath -Force
    return [PSCustomObject]@{ RunId = $runId; Status = "launch_failed"; Outcome = "launch_failed" }
}

# 4. Resolver comando a executar
$cmdExe = ""
$cmdArgs = @()

switch ($cond) {
    "NAT" {
        $cmdExe = $samplePath
    }
    "PIN" {
        $cmdExe = $pinExe.Path
        $cmdArgs = @("--", $samplePath)
    }
    "EMPTY" {
        $cmdExe = $pinExe.Path
        $cmdArgs = @("-t", $emptyToolDll.Path, "--", $samplePath)
    }
    default {
        # TMW0, TMW_DD, TMW_DP, TMW_DE, TMW_DM, TMW_DO, TMW_ALL
        $knobList = @()
        if ($PlanRow.knobs) {
            $knobList = ($PlanRow.knobs -split " ") | Where-Object { $_ -match "\S" }
        }
        $cmdExe = $pinExe.Path
        $cmdArgs = @("-t", $tomwareDll.Path) + $knobList + @("--", $samplePath)
    }
}

# 5. Execucao instrumentada com amostragem periodica
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$timedOut = $false
$controlledTermination = $false
$naturalCompletion = $false
$crash = $false
$exceptionCode = $null
$exitCode = $null
$rootPid = 0
$parentPid = $PID

$started = $false
$proc = $null
$observed = $null
try {
    $launchArgs = if ($cmdArgs -and $cmdArgs.Count -gt 0) { $cmdArgs } else { @() }
    $observed = Start-ObservedProcess -FilePath $cmdExe -ArgumentList $launchArgs `
        -WorkingDirectory (Split-Path -Parent $samplePath) `
        -StdoutPath $stdoutPath -StderrPath $stderrPath
    $proc = $observed.Process
    if ($proc) {
        $rootPid = $proc.Id
        $started = $true
    }
} catch {
    $started = $false
}

if (-not $started) {
    $sw.Stop()
    $endUtc = (Get-Date).ToUniversalTime().ToString("o")
    $failedRecord = [ordered]@{
        schema_version = 1
        identification = [ordered]@{
            campaign_id            = $campaignId
            run_id                 = $runId
            sample_id              = $sampleId
            sha256                 = $PlanRow.sha256
            block_id               = $PlanRow.block_id
            repetition             = [int]$PlanRow.repetition
            condition              = $cond
            modules_enabled        = @()
            run_order              = [int]$PlanRow.order_in_block
            random_seed            = [int]$PlanRow.random_seed
            host_id                = $env:COMPUTERNAME
            vm_id                  = ""
            snapshot_id            = ""
            restore_completed      = $false
            start_timestamp_utc    = $startUtc
            end_timestamp_utc      = $endUtc
            monotonic_duration_ms  = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            configuration_hash     = ""
        }
        operational_outcome = [ordered]@{
            launch_success              = $false
            pid                         = 0
            parent_pid                  = $PID
            natural_completion          = $false
            timeout                     = $false
            still_active_at_window_end  = $false
            controlled_termination      = $false
            crash                       = $false
            exception_code              = $null
            exit_code                   = $null
            termination_reason          = "launch_failed"
            observation_duration_ms     = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            time_to_first_activity_ms   = $null
            collector_failure           = $false
            missing_reason              = "start_process_failed"
        }
        timing_and_cpu = [ordered]@{
            wall_clock_ms      = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            cpu_user_ms        = 0
            cpu_kernel_ms      = 0
            cpu_total_ms       = 0
            cpu_percent_mean   = 0
            cpu_percent_max    = 0
            logical_processors = [Environment]::ProcessorCount
        }
        memory = [ordered]@{
            peak_working_set_bytes    = 0
            average_working_set_bytes = 0
            peak_private_bytes        = 0
            average_private_bytes     = 0
            sample_count              = 0
        }
        io = [ordered]@{
            bytes_read       = 0
            bytes_written    = 0
            read_operations  = 0
            write_operations = 0
            files_created    = @()
            files_modified   = @()
            files_deleted    = @()
        }
        processes_threads_modules = [ordered]@{
            peak_tracked_processes = 0
            peak_tracked_threads   = 0
            child_pids             = @()
            loaded_modules_count   = 0
        }
        behavioral_fidelity = [ordered]@{
            stdout_sha256 = ""
            stderr_sha256 = ""
            stdout_bytes  = 0
            stderr_bytes  = 0
        }
        artifacts = [ordered]@{
            raw_record_json_path      = $finalJsonPath
            stdout_path               = $stdoutPath
            stderr_path               = $stderrPath
            resource_time_series_path = $null
        }
    }
    $failedRecord | ConvertTo-Json -Depth 6 | Set-Content -Path $tempJsonPath -Encoding UTF8
    Move-Item -Path $tempJsonPath -Destination $finalJsonPath -Force
    return [PSCustomObject]@{ RunId = $runId; Status = "launch_failed"; Outcome = "launch_failed" }
}

# Loop de observacao periodica
$maxDurationSec = if ($prof -eq "persistent") { $windowSec } else { $timeoutSec }

$timeSeriesRows = [System.Collections.Generic.List[object]]::new()
$peakWs = [long]0
$peakPriv = [long]0
$wsSum = [double]0
$privSum = [double]0
$peakThreads = 0
$peakHandles = 0
$peakProcesses = 0
$allChildPids = [System.Collections.Generic.HashSet[int]]::new()
$loadedModules = @()

while (-not $proc.HasExited) {
    try { & shutdown.exe /a 2>$null | Out-Null } catch {}
    Start-Sleep -Milliseconds $samplingIntervalMs
    $elapsedSec = $sw.Elapsed.TotalSeconds

    $sampleMetrics = Get-ProcessMetricsSample -RootPid $rootPid -SampleBaseName ([System.IO.Path]::GetFileNameWithoutExtension($samplePath))
    $timeSeriesRows.Add($sampleMetrics)

    $peakWs = [Math]::Max($peakWs, $sampleMetrics.TotalWorkingSetBytes)
    $peakPriv = [Math]::Max($peakPriv, $sampleMetrics.TotalPrivateBytes)
    $wsSum += $sampleMetrics.TotalWorkingSetBytes
    $privSum += $sampleMetrics.TotalPrivateBytes
    $peakThreads = [Math]::Max($peakThreads, $sampleMetrics.TotalThreads)
    $peakHandles = [Math]::Max($peakHandles, $sampleMetrics.TotalHandles)
    $peakProcesses = [Math]::Max($peakProcesses, $sampleMetrics.ActiveProcessCount)

    foreach ($c in $sampleMetrics.ChildPids) {
        [void]$allChildPids.Add($c)
    }

    # Tenta ler modulos do processo raiz
    if ($loadedModules.Count -eq 0) {
        $loadedModules = Get-LoadedModulesSafe -Process $proc
    }

    # Criterio 1: Timeout de aplicacao curta
    if ($prof -eq "short_lived" -and $elapsedSec -ge $timeoutSec) {
        $timedOut = $true
        Stop-ProcessTreeGuaranteed -RootPid $rootPid -SamplePath $samplePath
        break
    }

    # Criterio 2: Termino controlado da janela de aplicacao persistente
    if ($prof -eq "persistent" -and $elapsedSec -ge $windowSec) {
        $controlledTermination = $true
        Stop-ProcessTreeGuaranteed -RootPid $rootPid -SamplePath $samplePath
        break
    }
}

if (-not $timedOut -and -not $controlledTermination) {
    $exitCode = Complete-ObservedProcess -Observed $observed -WaitMs 3000
    $naturalCompletion = $true
    if ($null -ne $exitCode -and ($exitCode -lt 0 -or $exitCode -gt 65535)) {
        $crash = $true
        $exceptionCode = "0x{0:X8}" -f $exitCode
    }
} else {
    [void](Complete-ObservedProcess -Observed $observed -WaitMs 500)
}

$sw.Stop()
$endUtc = (Get-Date).ToUniversalTime().ToString("o")

# Captura de I/O final
$ioSnapshot = Get-ProcessIoSnapshot -Process $proc

# Garantir termino completo
Stop-ProcessTreeGuaranteed -RootPid $rootPid -SamplePath $samplePath

# Garantir existencia dos arquivos stdout/stderr
if (-not (Test-Path $stdoutPath)) { Set-Content -Path $stdoutPath -Value "" -Encoding UTF8 }
if (-not (Test-Path $stderrPath)) { Set-Content -Path $stderrPath -Value "" -Encoding UTF8 }

$stdoutSha = (Get-FileHash -Path $stdoutPath -Algorithm SHA256).Hash.ToLower()
$stderrSha = (Get-FileHash -Path $stderrPath -Algorithm SHA256).Hash.ToLower()

# Salvar serie temporal de recursos
if ($timeSeriesRows.Count -gt 0) {
    $timeSeriesRows | Export-Csv -Path $timeSeriesPath -NoTypeInformation -Encoding UTF8
}

$sampleCount = $timeSeriesRows.Count
$avgWs = if ($sampleCount -gt 0) { $wsSum / $sampleCount } else { 0 }
$avgPriv = if ($sampleCount -gt 0) { $privSum / $sampleCount } else { 0 }

# Determinar motivo de termino mutuamente exclusivo
$termReason = "natural_exit"
if ($timedOut) { $termReason = "timeout_expired" }
elseif ($controlledTermination) { $termReason = "window_controlled_termination" }
elseif ($crash) { $termReason = "exception_crash" }
elseif ($naturalCompletion -and $null -eq $exitCode) { $termReason = "exited_before_limit_exit_code_unknown" }

# Ultimas metricas de CPU registradas na serie temporal
$finalCpuUser = 0
$finalCpuKernel = 0
$finalCpuTotal = 0
if ($sampleCount -gt 0) {
    $lastSample = $timeSeriesRows[$sampleCount - 1]
    $finalCpuUser = $lastSample.CpuUserMs
    $finalCpuKernel = $lastSample.CpuKernelMs
    $finalCpuTotal = $lastSample.CpuTotalMs
}

$meanCpuPercent = if ($sw.Elapsed.TotalSeconds -gt 0) {
    [Math]::Round(($finalCpuTotal / ($sw.Elapsed.TotalSeconds * 1000.0)) * 100.0, 2)
} else { 0 }

# Montar registro completo conforme run_record.schema.json
$record = [ordered]@{
    schema_version = 1
    identification = [ordered]@{
        campaign_id            = $campaignId
        run_id                 = $runId
        sample_id              = $sampleId
        sha256                 = $PlanRow.sha256
        block_id               = $PlanRow.block_id
        repetition             = [int]$PlanRow.repetition
        condition              = $cond
        modules_enabled        = if ($PlanRow.modules_enabled) { @($PlanRow.modules_enabled -split ";") } else { @() }
        run_order              = [int]$PlanRow.order_in_block
        random_seed            = [int]$PlanRow.random_seed
        host_id                = $env:COMPUTERNAME
        vm_id                  = ""
        snapshot_id            = ""
        restore_unit           = "block"
        restore_completed      = $true
        start_timestamp_utc    = $startUtc
        end_timestamp_utc      = $endUtc
        monotonic_duration_ms  = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
        tool_build_id          = "TOMWare_x64_Rel"
        tomware_sha256         = if ($tomwareDll) { (Get-FileHash $tomwareDll.Path -Algorithm SHA256).Hash.ToLower() } else { "" }
        empty_tool_sha256      = if ($emptyToolDll) { (Get-FileHash $emptyToolDll.Path -Algorithm SHA256).Hash.ToLower() } else { "" }
        pin_version            = "3.28.98749"
        collector_version      = "2.1.0"
        configuration_hash     = ""
    }
    operational_outcome = [ordered]@{
        launch_success              = $true
        pid                         = $rootPid
        parent_pid                  = $parentPid
        natural_completion          = $naturalCompletion
        timeout                     = $timedOut
        still_active_at_window_end  = $controlledTermination
        controlled_termination      = $controlledTermination
        crash                       = $crash
        exception_code              = $exceptionCode
        exit_code                   = $exitCode
        termination_reason          = $termReason
        observation_duration_ms     = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
        time_to_first_activity_ms   = 0
        collector_failure           = $false
        missing_reason              = $null
    }
    timing_and_cpu = [ordered]@{
        wall_clock_ms      = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
        cpu_user_ms        = $finalCpuUser
        cpu_kernel_ms      = $finalCpuKernel
        cpu_total_ms       = $finalCpuTotal
        cpu_percent_mean   = $meanCpuPercent
        cpu_percent_max    = $meanCpuPercent
        context_switches   = $null
        logical_processors = [Environment]::ProcessorCount
        cpu_affinity_mask  = $null
    }
    memory = [ordered]@{
        current_working_set_bytes   = $peakWs
        peak_working_set_bytes      = $peakWs
        average_working_set_bytes   = [Math]::Round($avgWs, 0)
        private_working_set_bytes   = $peakPriv
        private_bytes               = $peakPriv
        peak_private_bytes          = $peakPriv
        average_private_bytes       = [Math]::Round($avgPriv, 0)
        commit_bytes                = $null
        peak_commit_bytes           = $null
        page_faults                 = $null
        child_processes_memory_bytes = 0
        aggregate_tree_memory_bytes = $peakWs
        sample_count                = $sampleCount
        sampling_interval_ms        = $samplingIntervalMs
    }
    io = [ordered]@{
        bytes_read       = $ioSnapshot.BytesRead
        bytes_written    = $ioSnapshot.BytesWritten
        read_operations  = $ioSnapshot.ReadOperations
        write_operations = $ioSnapshot.WriteOperations
        files_created    = @()
        files_modified   = @()
        files_deleted    = @()
        output_artifacts_hashes = @{}
    }
    processes_threads_modules = [ordered]@{
        process_tree           = @()
        child_pids             = @($allChildPids)
        peak_tracked_processes = $peakProcesses
        peak_tracked_threads   = $peakThreads
        threads_created_count  = $null
        peak_handle_count      = $peakHandles
        loaded_modules_count   = $loadedModules.Count
        loaded_modules         = $loadedModules
    }
    registry_and_network = [ordered]@{
        registry_keys_queried         = @()
        registry_keys_modified        = @()
        registry_values_modified       = @()
        dns_queries_attempted         = @()
        connections_attempted         = @()
        external_network_blocked_count = 0
    }
    behavioral_fidelity = [ordered]@{
        stdout_sha256            = $stdoutSha
        stderr_sha256            = $stderrSha
        stdout_bytes             = (Get-Item $stdoutPath).Length
        stderr_bytes             = (Get-Item $stderrPath).Length
        basic_block_count        = $null
        instruction_count        = $null
        image_count              = $loadedModules.Count
        watched_api_hits         = @{}
        api_categories_frequency = @{}
        application_validator    = $null
    }
    module_counters = [ordered]@{
        counters_enabled = $false
    }
    artifacts = [ordered]@{
        raw_record_json_path      = $finalJsonPath
        stdout_path               = $stdoutPath
        stderr_path               = $stderrPath
        resource_time_series_path = if ($sampleCount -gt 0) { $timeSeriesPath } else { $null }
        behavior_log_path         = $null
        module_events_path        = $null
    }
}

# 6. Gravacao Atomica: primeiro em .tmp, depois Move-Item
$record | ConvertTo-Json -Depth 8 | Set-Content -Path $tempJsonPath -Encoding UTF8
Move-Item -Path $tempJsonPath -Destination $finalJsonPath -Force

Write-Host ("    [OK] Run {0} ({1}) dur={2:N1}s outcome={3} ws_peak={4:N1}MB" -f `
    $runId, $cond, $sw.Elapsed.TotalSeconds, $termReason, ($peakWs / 1MB)) -ForegroundColor Green

$global:LASTEXITCODE = 0
return [PSCustomObject]@{
    RunId              = $runId
    Condition          = $cond
    DurationMs         = $sw.Elapsed.TotalMilliseconds
    TerminationReason  = $termReason
    PeakWorkingSetMB   = [Math]::Round($peakWs / 1MB, 2)
    CpuTotalMs         = $finalCpuTotal
    JsonPath           = $finalJsonPath
}
