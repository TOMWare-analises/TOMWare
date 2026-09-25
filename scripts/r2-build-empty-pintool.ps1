#Requires -Version 5.1
<#
.SYNOPSIS
  Build EmptyPinTool.dll (+ optional FidelityProbe.dll) for Reviewer 2.

.EXAMPLE
  cd C:\TOMWare
  .\scripts\r2-build-empty-pintool.ps1 -AlsoFidelityProbe

  # VM without VS/MSBuild: copy DLLs from host then:
  .\scripts\r2-build-empty-pintool.ps1 -RequirePresentOnly -AlsoFidelityProbe
#>
[CmdletBinding()]
param(
    [switch]$AlsoFidelityProbe,
    [switch]$RequirePresentOnly,
    [string]$RepoRoot = "",
    [string]$Configuration = "Release",
    [string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $RepoRoot

$outDir = Join-Path $RepoRoot "$Platform\$Configuration"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Assert-Dll([string]$Name) {
    $p = Join-Path $outDir $Name
    if (-not (Test-Path $p)) {
        throw @"
Missing $p

VM without Visual Studio/MSBuild: copy from the host machine:
  D:\MMB\workspace\tomware-melhorias\TOMWare\x64\Release\$Name
to:
  C:\TOMWare\x64\Release\$Name

Then re-run:
  .\scripts\r2-build-empty-pintool.ps1 -RequirePresentOnly -AlsoFidelityProbe
"@
    }
    Write-Host "OK $p ($([Math]::Round((Get-Item $p).Length/1MB, 2)) MB)" -ForegroundColor Green
}

if ($RequirePresentOnly) {
    Assert-Dll "EmptyPinTool.dll"
    if ($AlsoFidelityProbe) { Assert-Dll "FidelityProbe.dll" }
    Write-Host "DLLs present; skipping MSBuild." -ForegroundColor Cyan
    return
}

$emptyExists = Test-Path (Join-Path $outDir "EmptyPinTool.dll")
$fidExists = Test-Path (Join-Path $outDir "FidelityProbe.dll")

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msbuild = $null
if (Test-Path $vswhere) {
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" |
        Select-Object -First 1
}
if (-not $msbuild) {
    $candidates = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $msbuild = $c; break } }
}

if (-not $msbuild) {
    if ($emptyExists -and ((-not $AlsoFidelityProbe) -or $fidExists)) {
        Write-Host "MSBuild not found, but required DLLs already in $outDir — continuing." -ForegroundColor Yellow
        Assert-Dll "EmptyPinTool.dll"
        if ($AlsoFidelityProbe) { Assert-Dll "FidelityProbe.dll" }
        return
    }
    throw @"
MSBuild.exe not found on this VM.

Copy prebuilt DLLs from the HOST to the VM:

  Host: D:\MMB\workspace\tomware-melhorias\TOMWare\x64\Release\EmptyPinTool.dll
  Host: D:\MMB\workspace\tomware-melhorias\TOMWare\x64\Release\FidelityProbe.dll
    VM: C:\TOMWare\x64\Release\

Then:
  .\scripts\r2-build-empty-pintool.ps1 -RequirePresentOnly -AlsoFidelityProbe
  .\scripts\r2-run-all-vm.ps1 -SkipSkew -IncludeFidelity
"@
}

function Build-Proj([string]$Proj, [string]$DllName) {
    if (-not (Test-Path $Proj)) { throw "Missing project: $Proj" }
    Write-Host "MSBuild $Proj ($Configuration|$Platform)" -ForegroundColor Cyan
    $slnDir = $RepoRoot
    if (-not $slnDir.EndsWith("\")) { $slnDir += "\" }
    & $msbuild $Proj `
        /p:Configuration=$Configuration `
        /p:Platform=$Platform `
        /p:SolutionDir=$slnDir `
        /m /v:minimal
    if ($LASTEXITCODE -ne 0) { throw "MSBuild failed for $Proj (exit $LASTEXITCODE)" }

    $expected = Join-Path $outDir $DllName
    if (-not (Test-Path $expected)) {
        $projDir = Split-Path -Parent $Proj
        $fallback = Join-Path $projDir "$Platform\$Configuration\$DllName"
        if (Test-Path $fallback) {
            Copy-Item $fallback $expected -Force
            Write-Host "Copied $fallback -> $expected" -ForegroundColor DarkCyan
        }
    }
    if (-not (Test-Path $expected)) { throw "Expected output missing: $expected" }
    Write-Host "OK $expected" -ForegroundColor Green
}

Build-Proj (Join-Path $RepoRoot "EmptyPinTool\EmptyPinTool.vcxproj") "EmptyPinTool.dll"

if ($AlsoFidelityProbe) {
    Build-Proj (Join-Path $RepoRoot "FidelityProbe\FidelityProbe.vcxproj") "FidelityProbe.dll"
}

Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  .\scripts\r2-run-all-vm.ps1 -SkipSkew -IncludeFidelity" -ForegroundColor Yellow
