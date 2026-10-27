#Requires -Version 5.1
<#
.SYNOPSIS
  Preflight: confirma que cada amostra do plano/corpus existe como .exe na VM.
  Distingue ZIP ainda nao extraido de ficheiro realmente em falta.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$CampaignId = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}

function Find-SampleExe {
    param([string]$Sha256)
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

function Find-SampleZip {
    param([string]$Sha256)
    $shaL = $Sha256.ToLower()
    $zipDir = Join-Path $RepoRoot "samples\infected"
    if (-not (Test-Path $zipDir)) { return $null }
    $p = Join-Path $zipDir "$shaL.zip"
    if (Test-Path $p) { return $p }
    return $null
}

$samples = @()
if ($CampaignId) {
    $manifestPath = Join-Path $RepoRoot ("experiment\campaigns\" + $CampaignId + "\campaign.json")
    if (-not (Test-Path $manifestPath)) {
        throw "campaign.json nao encontrado: $manifestPath"
    }
    $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $samples = @($manifest.samples)
} else {
    $corpusPath = Join-Path $RepoRoot "experiment\corpus\corpus.csv"
    $samples = @(Import-Csv -Path $corpusPath -Encoding UTF8 | Where-Object { $_.included -eq "true" })
}

$ok = 0
$missing = New-Object System.Collections.Generic.List[object]
$zipOnly = New-Object System.Collections.Generic.List[object]

foreach ($s in $samples) {
    $sid = $s.sample_id
    $sha = [string]$s.sha256
    $grp = [string]$s.group
    $exe = Find-SampleExe -Sha256 $sha
    if ($exe) {
        $ok++
        continue
    }
    $zip = Find-SampleZip -Sha256 $sha
    $row = [PSCustomObject]@{
        sample_id = $sid
        group     = $grp
        sha256    = $sha.ToLower()
        zip_found = [bool]$zip
    }
    if ($zip) { $zipOnly.Add($row) } else { $missing.Add($row) }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  TOMWare.M - Preflight de amostras" -ForegroundColor Cyan
if ($CampaignId) { Write-Host "  Campanha: $CampaignId" -ForegroundColor Cyan }
Write-Host "  RepoRoot: $RepoRoot" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ("Planejadas : {0}" -f $samples.Count)
Write-Host ("EXE OK     : {0}" -f $ok) -ForegroundColor Green
Write-Host ("ZIP so zip : {0}  (falta Extract-InfectedVM.ps1)" -f $zipOnly.Count) -ForegroundColor Yellow
Write-Host ("Em falta   : {0}" -f $missing.Count) -ForegroundColor $(if ($missing.Count -gt 0) { "Red" } else { "Green" })

if ($zipOnly.Count -gt 0) {
    Write-Host "`nZIPs presentes mas ainda nao extraidos para .exe:" -ForegroundColor Yellow
    $zipOnly | Select-Object -First 20 | Format-Table -AutoSize
    if ($zipOnly.Count -gt 20) { Write-Host ("  ... e mais {0}" -f ($zipOnly.Count - 20)) }
    Write-Host "Comando: powershell -ExecutionPolicy Bypass -File experiment\scripts\runner\Extract-InfectedVM.ps1"
}

if ($missing.Count -gt 0) {
    Write-Host "`nAmostras sem EXE e sem ZIP:" -ForegroundColor Red
    $missing | Format-Table -AutoSize
}

$reportDir = Join-Path $RepoRoot "experiment\corpus"
if ($CampaignId) {
    $reportDir = Join-Path $RepoRoot ("experiment\campaigns\" + $CampaignId + "\processed")
}
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
}
$reportPath = Join-Path $reportDir "preflight_presence.csv"
$allRows = @()
$allRows += $zipOnly
$allRows += $missing
if ($allRows.Count -gt 0) {
    $allRows | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Relatorio: $reportPath"
}

if (($missing.Count + $zipOnly.Count) -gt 0) {
    Write-Host "`nPREFLIGHT FALHOU. Nao inicie a campanha." -ForegroundColor Red
    exit 1
}

Write-Host "`nPREFLIGHT OK. Todas as amostras existem como .exe." -ForegroundColor Green
exit 0
