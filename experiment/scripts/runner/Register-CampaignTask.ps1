#Requires -Version 5.1
<#
.SYNOPSIS
  Agenda a campanha numa tarefa oculta (nao depende da janela do PowerShell).
  NAO isola malware: se o SO for comprometido, a tarefa tambem pode morrer.
  Use isto so como complemento. O isolamento real e o revert no HOST.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CampaignId,
    [string]$RepoRoot = "C:\TOMWare",
    [string]$BlockId = ""
)

$runner = Join-Path $RepoRoot "experiment\scripts\runner\Run-Campaign.ps1"
$logDir = Join-Path $RepoRoot ("experiment\campaigns\" + $CampaignId + "\logs")
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir "task_stdout.log"

$arg = "-NoProfile -ExecutionPolicy Bypass -File `"$runner`" -CampaignId $CampaignId"
if ($BlockId) { $arg = $arg + " -BlockId $BlockId" }

$tr = "powershell.exe $arg >> `"$log`" 2>&1"
schtasks /Create /TN "TOMWareCampaign" /SC ONCE /ST 00:00 /SD 01/01/2099 /RU SYSTEM /RL HIGHEST /F /TR $tr | Out-Null
schtasks /Run /TN "TOMWareCampaign" | Out-Null
Write-Host "Tarefa TOMWareCampaign iniciada (oculta). Log: $log" -ForegroundColor Green
Write-Host "Isto NAO substitui snapshot revert no host." -ForegroundColor Yellow
