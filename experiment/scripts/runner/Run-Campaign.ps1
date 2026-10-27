#Requires -Version 5.1
<#
.SYNOPSIS
  Orquestrador mestre de execucao experimental (TOMWare.M).
  Executa campanhas a partir do execution_plan.csv com controle de bloco,
  gravacao incremental e auditabilidade total.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CampaignId,
    [string]$RepoRoot = "",
    [switch]$DryRun = $false,
    [int]$Limit = 0,
    [string]$SampleId = "",
    [string]$Condition = "",
    [string]$RunId = "",
    [string]$BlockId = "",
    [int]$Repetition = 0,
    [string]$SkipRunIds = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}
Set-Location $RepoRoot

$configPath = Join-Path $RepoRoot "experiment/config/experiment.config.json"
if (-not (Test-Path $configPath)) { throw "Config nao encontrada: $configPath" }
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$campaignDir = Join-Path $RepoRoot ("experiment/campaigns/" + $CampaignId)
if (-not (Test-Path $campaignDir)) { throw "Diretorio de campanha nao encontrado: $campaignDir" }

# Garantir criacao de todos os diretorios da campanha
foreach ($sub in @("raw/runs", "raw/resources", "raw/stdout", "raw/stderr", "raw/behavior", "raw/module_events", "processed", "reports/tables", "reports/figures")) {
    $targetSub = Join-Path $campaignDir $sub
    if (-not (Test-Path $targetSub)) {
        New-Item -ItemType Directory -Force -Path $targetSub | Out-Null
    }
}

$planPath = Join-Path $campaignDir "execution_plan.csv"
if (-not (Test-Path $planPath)) { throw "execution_plan.csv nao encontrado: $planPath" }

$manifestPath = Join-Path $campaignDir "campaign.json"
$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  TOMWare.M - Execucao da Campanha: $CampaignId" -ForegroundColor Cyan
Write-Host "  Modo Piloto: $($manifest.pilot_mode) | Repeticoes: $($manifest.repetitions)" -ForegroundColor Cyan
Write-Host "  Semente: $($manifest.random_seed) | Total Planejado: $($manifest.total_planned_runs)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$planRows = Import-Csv -Path $planPath -Encoding UTF8

if ($BlockId) {
    $planRows = @($planRows | Where-Object { $_.block_id -eq $BlockId })
}
if ($SampleId) {
    $planRows = @($planRows | Where-Object { $_.sample_id -eq $SampleId })
}
if ($Repetition -gt 0) {
    $planRows = @($planRows | Where-Object { [int]$_.repetition -eq $Repetition })
}
if ($Condition) {
    $planRows = @($planRows | Where-Object { $_.condition -eq $Condition })
}
if ($RunId) {
    $planRows = @($planRows | Where-Object { $_.run_id -eq $RunId })
}
if ($SkipRunIds) {
    $skipSet = @{}
    foreach ($id in ($SkipRunIds -split ",")) {
        $t = $id.Trim()
        if ($t) { $skipSet[$t] = $true }
    }
    $before = $planRows.Count
    $planRows = @($planRows | Where-Object { -not $skipSet.ContainsKey($_.run_id) })
    Write-Host ("SkipRunIds: {0} ja no host, restam {1}" -f ($before - $planRows.Count), $planRows.Count) -ForegroundColor DarkGray
}
if ($Limit -gt 0) {
    $planRows = @($planRows | Select-Object -First $Limit)
}

$totalToRun = $planRows.Count
Write-Host "Execucoes selecionadas para esta rodada: $totalToRun" -ForegroundColor Yellow

$logDir = Join-Path $campaignDir "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}
$transcriptPath = Join-Path $logDir "campaign_transcript.log"
$heartbeatPath = Join-Path $logDir "heartbeat.txt"
try { Start-Transcript -Path $transcriptPath -Append -ErrorAction SilentlyContinue | Out-Null } catch {}

$hbBlock = $BlockId
if (-not $hbBlock -and $planRows.Count -gt 0) { $hbBlock = [string]$planRows[0].block_id }
function Write-CampaignHeartbeat {
    param([int]$Idx, [string]$RunIdValue, [string]$Status)
    try {
        $hb = "utc={0} idx={1}/{2} run_id={3} block={4} status={5}" -f (Get-Date).ToUniversalTime().ToString("o"), $Idx, $totalToRun, $RunIdValue, $hbBlock, $Status
        Set-Content -Path $heartbeatPath -Value $hb -Encoding ASCII
    } catch {}
}
Write-CampaignHeartbeat -Idx 0 -RunIdValue "start" -Status "start"

if (-not $DryRun -and -not $BlockId) {
    $preflightScript = Join-Path $RepoRoot "experiment/scripts/runner/Test-CorpusPresence.ps1"
    if (-not (Test-Path $preflightScript)) {
        throw "Preflight nao encontrado: $preflightScript"
    }
    Write-Host "`n--- Preflight de amostras ---" -ForegroundColor Cyan
    & $preflightScript -RepoRoot $RepoRoot -CampaignId $CampaignId
    if ($LASTEXITCODE -ne 0) {
        throw "Preflight falhou: ha amostras em falta ou ZIP nao extraido. Campanha abortada."
    }
}

$singleRunScript = Join-Path $RepoRoot "experiment/scripts/runner/Invoke-SingleRun.ps1"
$processedDir = Join-Path $campaignDir "processed"
if (-not (Test-Path $processedDir)) {
    New-Item -ItemType Directory -Force -Path $processedDir | Out-Null
}
$metricsCsvPath = Join-Path $processedDir "run_metrics.csv"

function Start-TomwareShutdownAbortWatchdog {
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

$processedRows = [System.Collections.Generic.List[object]]::new()
$currentBlockId = ""
$idx = 0
$swTotal = [System.Diagnostics.Stopwatch]::StartNew()
$watchdog = $null
if ($totalToRun -gt 0) {
    $watchdog = Start-TomwareShutdownAbortWatchdog
}

try {
    foreach ($row in $planRows) {
        $idx++
        $pct = [Math]::Round(($idx / $totalToRun) * 100.0, 1)

        # Controle de bloco e isolamento
        if ($row.block_id -ne $currentBlockId) {
            $currentBlockId = $row.block_id
            Write-Host "`n=== INICIANDO BLOCO: $currentBlockId (Amostra: $($row.sample_id), Rep: $($row.repetition)) ===" -ForegroundColor Magenta
            
            # Hook de isolamento por bloco (restauracao de snapshot se configurado)
            # Em ambiente sem automacao de hipervisor, verifica processos residuais
            . (Join-Path $RepoRoot "experiment/scripts/collectors/ProcessCollector.ps1")
            Stop-ProcessTreeGuaranteed
        }

        $progressMsg = "[{0}/{1} - {2}%] Executando {3} | Condicao: {4} (Ordem no bloco: {5})" -f $idx, $totalToRun, $pct, $row.run_id, $row.condition, $row.order_in_block
        Write-Host $progressMsg -ForegroundColor White

        $res = $null
        try {
            $res = & $singleRunScript -PlanRow $row -RepoRoot $RepoRoot -CampaignDir $campaignDir -Config $config -DryRun:$DryRun
        } catch {
            Write-Host "    [ERRO] Excecao ao executar $($row.run_id): $_" -ForegroundColor Red
        }
        $global:LASTEXITCODE = 0

        Write-CampaignHeartbeat -Idx $idx -RunIdValue $row.run_id -Status $(if ($res) { [string]$res.Status } else { "error" })

        if ($res -and $res.JsonPath -and (Test-Path $res.JsonPath)) {
            try {
                $jsonContent = Get-Content $res.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $summaryRow = [PSCustomObject]@{
                    run_id                 = $row.run_id
                    campaign_id            = $row.campaign_id
                    block_id               = $row.block_id
                    sample_id              = $row.sample_id
                    sha256                 = $row.sha256
                    group                  = $row.group
                    execution_profile      = $row.execution_profile
                    repetition             = $row.repetition
                    condition              = $row.condition
                    order_in_block         = $row.order_in_block
                    launch_success         = $jsonContent.operational_outcome.launch_success
                    natural_completion     = $jsonContent.operational_outcome.natural_completion
                    timeout                = $jsonContent.operational_outcome.timeout
                    controlled_termination = $jsonContent.operational_outcome.controlled_termination
                    crash                  = $jsonContent.operational_outcome.crash
                    exit_code              = $jsonContent.operational_outcome.exit_code
                    termination_reason     = $jsonContent.operational_outcome.termination_reason
                    wall_clock_ms          = $jsonContent.timing_and_cpu.wall_clock_ms
                    cpu_total_ms           = $jsonContent.timing_and_cpu.cpu_total_ms
                    cpu_user_ms            = $jsonContent.timing_and_cpu.cpu_user_ms
                    cpu_kernel_ms          = $jsonContent.timing_and_cpu.cpu_kernel_ms
                    peak_working_set_bytes = $jsonContent.memory.peak_working_set_bytes
                    peak_private_bytes     = $jsonContent.memory.peak_private_bytes
                    sample_count           = $jsonContent.memory.sample_count
                    stdout_sha256          = $jsonContent.behavioral_fidelity.stdout_sha256
                    stderr_sha256          = $jsonContent.behavioral_fidelity.stderr_sha256
                }
                $processedRows.Add($summaryRow)
            } catch {}
        }
    }
} finally {
    Stop-TomwareShutdownAbortWatchdog -Handle $watchdog
    try { Stop-Transcript | Out-Null } catch {}
}

$swTotal.Stop()

# Consolidar run_metrics.csv
if ($processedRows.Count -gt 0) {
    $processedRows | Export-Csv -Path $metricsCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "`nResumo gravado em: $metricsCsvPath" -ForegroundColor Green
}

$totalMinutes = [Math]::Round($swTotal.Elapsed.TotalMinutes, 2)
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Campanha concluida em $totalMinutes minutos." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

$global:LASTEXITCODE = 0
[System.Environment]::Exit(0)
