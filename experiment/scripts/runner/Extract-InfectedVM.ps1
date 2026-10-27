#Requires -Version 5.1
<#
.SYNOPSIS
  Extrai e prepara as amostras infectadas para execucao exclusiva na VM isolada.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\TOMWare"
)

$ErrorActionPreference = "Stop"

$sevenZip = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) {
    throw "7-Zip nao encontrado em $sevenZip. Instale o 7-Zip na VM."
}

$srcDir = Join-Path $RepoRoot "samples\infected"
$dstDir = Join-Path $RepoRoot "malwares\infected"

if (-not (Test-Path $srcDir)) {
    throw "Diretorio de origem nao encontrado: $srcDir"
}

New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

# 1. Adicionar exclusao do Defender na VM
try {
    Add-MpPreference -ExclusionPath $dstDir -ErrorAction SilentlyContinue
    Write-Host "Exclusao do Defender configurada para: $dstDir" -ForegroundColor Green
} catch {}

# 2. Extrair arquivos zip principais
$zips = Get-ChildItem -Path $srcDir -Filter "*.zip"
Write-Host "Extraindo $($zips.Count) arquivos zip para $dstDir..." -ForegroundColor Cyan

foreach ($z in $zips) {
    & $sevenZip x $z.FullName "-o$dstDir" -pinfected -y | Out-Null
}

# 3. Extrair zips aninhados se houver
$nestedZips = Get-ChildItem -Path $dstDir -Filter "*.zip"
if ($nestedZips.Count -gt 0) {
    Write-Host "Extraindo $($nestedZips.Count) zips aninhados..." -ForegroundColor Cyan
    foreach ($nz in $nestedZips) {
        & $sevenZip x $nz.FullName "-o$dstDir" -pinfected -y | Out-Null
        Remove-Item $nz.FullName -Force -ErrorAction SilentlyContinue
    }
}

# 4. Renomear executaveis para <SHA256>.exe se ainda nao estiverem
$exes = Get-ChildItem -Path $dstDir -Filter "*.exe"
foreach ($e in $exes) {
    if ($e.BaseName -notmatch '^[0-9a-fA-F]{64}$') {
        $hash = (Get-FileHash -Path $e.FullName -Algorithm SHA256).Hash.ToLower()
        $target = Join-Path $dstDir "$hash.exe"
        if (-not (Test-Path $target)) {
            Rename-Item -Path $e.FullName -NewName "$hash.exe" -Force
            Write-Host "Renomeado $($e.Name) -> $hash.exe" -ForegroundColor Green
        } else {
            Remove-Item $e.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

# 5. Limpar arquivos auxiliares nao-executaveis (.doc, .msi, .txt, etc.) de malwares/infected
Get-ChildItem -Path $dstDir -File | Where-Object { $_.Extension -ne '.exe' } | Remove-Item -Force -ErrorAction SilentlyContinue

$finalExes = Get-ChildItem -Path $dstDir -Filter "*.exe"
Write-Host "`n=== Concluido com sucesso! ===" -ForegroundColor Green
Write-Host "Total de amostras prontas em $dstDir : $($finalExes.Count)" -ForegroundColor Green
$finalExes | Select-Object Name, Length | Format-Table -AutoSize
