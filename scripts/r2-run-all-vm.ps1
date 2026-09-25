#Requires -Version 5.1
<#
.SYNOPSIS
  VM driver for Reviewer 2 remaining Pin-dependent experiments.

.EXAMPLE
  cd C:\TOMWare
  .\scripts\r2-run-all-vm.ps1 -SkipSkew -IncludeFidelity
#>
[CmdletBinding()]
param(
    [switch]$SkipSkew,
    [switch]$SkipLadder,
    [switch]$SkipFidelity,
    [switch]$IncludeCorpusLadder,
    [switch]$IncludeFidelity,
    [switch]$ForceBuild,
    [int]$SkewN = 30
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

Write-Host "TOMWare R2 VM batch @ $RepoRoot" -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $RepoRoot "pin\pin.exe"))) { throw "pin.exe missing" }
if (-not (Test-Path (Join-Path $RepoRoot "x64\Release\TOMWare.dll"))) { throw "TOMWare.dll missing - build Release|x64 first" }

$evRoot = Join-Path $RepoRoot "Resultados\evidencias_VM_R2"
New-Item -ItemType Directory -Force -Path $evRoot | Out-Null
Write-Host "Evidence output: $evRoot" -ForegroundColor DarkCyan

$emptyDll = Join-Path $RepoRoot "x64\Release\EmptyPinTool.dll"
$fidDll = Join-Path $RepoRoot "x64\Release\FidelityProbe.dll"
$needEmpty = (-not $SkipLadder) -or $IncludeFidelity
$needFid = $IncludeFidelity -and (-not $SkipFidelity)

if ($ForceBuild -or ($needEmpty -and -not (Test-Path $emptyDll)) -or ($needFid -and -not (Test-Path $fidDll))) {
    Write-Host "== Build EmptyPinTool / FidelityProbe ==" -ForegroundColor Yellow
    $buildArgs = @{ RepoRoot = $RepoRoot }
    if ($needFid) { $buildArgs["AlsoFidelityProbe"] = $true }
    if ((Test-Path $emptyDll) -and ((-not $needFid) -or (Test-Path $fidDll)) -and -not $ForceBuild) {
        $buildArgs["RequirePresentOnly"] = $true
    }
    & (Join-Path $RepoRoot "scripts\r2-build-empty-pintool.ps1") @buildArgs
} else {
    if (Test-Path $emptyDll) {
        Write-Host "Using existing EmptyPinTool.dll (skip MSBuild)" -ForegroundColor DarkCyan
    }
    if ($needFid -and (Test-Path $fidDll)) {
        Write-Host "Using existing FidelityProbe.dll (skip MSBuild)" -ForegroundColor DarkCyan
    }
}

if ($needEmpty -and -not (Test-Path $emptyDll)) {
    throw "EmptyPinTool.dll missing at $emptyDll — copy from host x64\Release\"
}
if ($needFid -and -not (Test-Path $fidDll)) {
    throw "FidelityProbe.dll missing at $fidDll — copy from host x64\Release\"
}

if (-not $SkipSkew) {
    Write-Host "== SkewMask fixed N=$SkewN ==" -ForegroundColor Yellow
    & (Join-Path $RepoRoot "scripts\r2-skewmask-fixedN.ps1") -N $SkewN -RepoRoot $RepoRoot `
        -OutDir (Join-Path $evRoot "skewmask_redesign_N$SkewN") -TimeoutSeconds 120
}

if (-not $SkipLadder) {
    Write-Host "== Baseline ladder oracles ==" -ForegroundColor Yellow
    $mode = if ($IncludeCorpusLadder) { "both" } else { "oracles" }
    & (Join-Path $RepoRoot "scripts\r2-baseline-ladder.ps1") -Mode $mode -RepoRoot $RepoRoot `
        -OutDir (Join-Path $evRoot "baseline_ladder") -TimeoutSeconds 45 -Repeat 3
}

if ($IncludeFidelity -and -not $SkipFidelity) {
    Write-Host "== Behavioral fidelity (subset-6) ==" -ForegroundColor Yellow
    & (Join-Path $RepoRoot "scripts\r2-behavioral-fidelity.ps1") -RepoRoot $RepoRoot `
        -OutDir (Join-Path $evRoot "behavioral_fidelity") -TimeoutSeconds 45 -Repeat 1
}

Write-Host "VM batch finished. Copy folders from Resultados\evidencias_VM_R2 back to host." -ForegroundColor Green
Write-Host "  - baseline_ladder" -ForegroundColor Green
Write-Host "  - behavioral_fidelity (if -IncludeFidelity)" -ForegroundColor Green
