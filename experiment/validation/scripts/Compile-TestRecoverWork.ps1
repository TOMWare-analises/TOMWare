#Requires -Version 5.1
# Host or VM. Produces x64 TestRecoverWork.exe. Does not run Pin.
param(
    [string]$Src = "",
    [string]$OutExe = ""
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $PSCommandPath
$sibling = Join-Path $here "TestRecoverWork.cpp"
$repoGuess = Join-Path $here "..\..\..\Resultados\Apps-Teste-src\TestRecoverWork\TestRecoverWork.cpp"
if (-not $Src) {
    if (Test-Path -LiteralPath $sibling) { $Src = $sibling }
    elseif (Test-Path -LiteralPath $repoGuess) { $Src = (Resolve-Path $repoGuess).Path }
}
if (-not $OutExe) {
    if (Test-Path -LiteralPath (Join-Path $here "..\..\..\Resultados\Apps-Teste")) {
        $OutExe = Join-Path $here "..\..\..\Resultados\Apps-Teste\TestRecoverWork.exe"
    } else {
        $OutExe = Join-Path $here "TestRecoverWork.exe"
    }
}
if (-not (Test-Path -LiteralPath $Src)) { throw "source missing: $Src" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutExe) | Out-Null

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$cl = $null
if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vs) {
        $aux = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path $aux) {
            $outDir = Split-Path -Parent $OutExe
            $obj = Join-Path $outDir "TestRecoverWork.obj"
            $cmd = "`"$aux`" && cl /nologo /O2 /EHsc /W3 /DUNICODE /D_UNICODE /Fo:`"$obj`" /Fe:`"$OutExe`" `"$Src`""
            cmd /c $cmd
            if ($LASTEXITCODE -ne 0) { throw "cl failed" }
            $cl = $OutExe
        }
    }
}
if (-not $cl) {
    $gxx = Get-Command g++ -ErrorAction SilentlyContinue
    if ($gxx) {
        & $gxx.Source -O2 -municode -DUNICODE -D_UNICODE -o $OutExe $Src
        if ($LASTEXITCODE -ne 0) { throw "g++ failed" }
        $cl = $OutExe
    }
}
if (-not $cl -or -not (Test-Path -LiteralPath $OutExe)) {
    throw "No MSVC cl.exe (vcvars64) or g++. Compile on the VM after installing Build Tools, or copy a prebuilt x64 exe."
}
$h = (Get-FileHash -LiteralPath $OutExe -Algorithm SHA256).Hash
Write-Host ("EXE {0}" -f $OutExe)
Write-Host ("SHA-256 {0}" -f $h)
Write-Host "Controlled demonstrator. Not a malware case."
