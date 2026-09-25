#Requires -Version 5.1
<#
.SYNOPSIS
  Extract password-protected infected sample ZIPs for R2-6 fidelity.

.EXAMPLE
  cd C:\TOMWare
  .\scripts\r2-extract-infected.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$ZipPassword = "infected",
    [switch]$AddDefenderExclusions
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $RepoRoot

$src = Join-Path $RepoRoot "samples\infected"
$dst = Join-Path $RepoRoot "malwares\infected"
$pwFile = Join-Path $src "password.txt"
if (Test-Path $pwFile) {
    $ZipPassword = (Get-Content $pwFile -TotalCount 1).Trim()
}

if (-not (Test-Path $src)) { throw "Missing $src" }
New-Item -ItemType Directory -Force -Path $dst | Out-Null

Write-Host "Extract infected ZIPs" -ForegroundColor Cyan
Write-Host "  Source: $src"
Write-Host "  Dest:   $dst"
Write-Host "  Pass:   (from password.txt / default)"

$extract = Join-Path $RepoRoot "scripts\extract-malware-samples.ps1"
$args = @{
    SourceDir    = $src
    DestDir      = $dst
    ZipPassword  = $ZipPassword
    RenameToSha256 = $true
}
if ($AddDefenderExclusions) { $args["AddDefenderExclusions"] = $true }

& $extract @args

$exes = @(Get-ChildItem $dst -Filter "*.exe" -File -ErrorAction SilentlyContinue)
Write-Host ("Extracted/available EXEs: {0}" -f $exes.Count) -ForegroundColor Green
$exes | Select-Object -First 20 Name, Length | Format-Table -AutoSize
Write-Host "Next: .\scripts\r2-behavioral-fidelity.ps1 -MalwareOnly" -ForegroundColor Yellow
Write-Host "  then: .\scripts\r2-behavioral-fidelity.ps1 -AllInfected -SkipBenign" -ForegroundColor Yellow
