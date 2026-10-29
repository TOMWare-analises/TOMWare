#Requires -Version 5.1
# JCVHT c05a1271 — controlled recovery (1) + benign progress (5).
# Does NOT mark identified=true. Does NOT restore snapshots.
# TMW0 = Pin + TOMWare.dll knobs off (-q). Campaign DLL prefix 4BBC6270.
# Restore tomware_go BETWEEN arms, after copying OutDir to the host.
param(
    [ValidateSet("Prepare", "CTRL", "PROG")][string]$Job = "Prepare",
    [ValidateSet("Native", "TMW0", "DP")][string]$Mode = "Native",
    [ValidatePattern("^[A-Za-z0-9_-]*$")][string]$SampleId = "",
    [string]$RepoRoot = "C:\TOMWare",
    [string]$ScriptsDir = "C:\TOMWare\m3_v12_scripts",
    [string]$OutDir = "C:\TOMWare\m3_ctrl_progress",
    [string]$ExpectedDllSha256 = "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6"
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "Run only inside the Windows analysis VM." }

$runner = Join-Path $ScriptsDir "Run-M3-CaseStudy.ps1"
if (-not (Test-Path -LiteralPath $runner)) { throw "v12 runner missing: $runner" }

$Progress = [ordered]@{
    BEN_05 = "0244aa8269c39e74663920ca738fec27bde0a1bb6667feb24299903864337f12"
    BEN_06 = "0436f44255d26e463fe9554d30f5f681bec9aaec14fb8ef53acbdea838b1f39d"
    BEN_10 = "064181108cd8d7f110cc11b84dbf2d7f18fd5f52a2ee989985d88a969f093dbe"
    BEN_12 = "070a98b4f7c03f99048a10f490d5916a9a98417e0d0de2c414c76b3dd00cb35e"
    BEN_16 = "07c1f3b3ddc138d037acad8ee6eaa54488b4918861bdaff3fc4ae9796ae79d1c"
}

function Assert-Dll([string]$Root, [string]$Expected) {
    $dll = Join-Path $Root "x64\Release\TOMWare.dll"
    if (-not (Test-Path -LiteralPath $dll)) { throw "TOMWare.dll missing: $dll" }
    $h = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash.ToUpperInvariant()
    Write-Host ("DLL SHA-256 {0}" -f $h)
    if ($h -ne $Expected.ToUpperInvariant()) { throw "DLL differs from campaign 4BBC6270. Stop." }
}

function Find-HashExe([string]$Sha, [string]$Root) {
    $shaU = $Sha.ToUpperInvariant(); $shaL = $Sha.ToLowerInvariant()
    $names = @("$shaL.exe", "$shaU.exe", $shaL, $shaU)
    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($d in @(
            (Join-Path $Root "samples\benign"),
            (Join-Path $Root "samples\benign\JCVHT_PROG5_BENIGN"),
            (Join-Path $Root "malwares\benign"),
            (Join-Path $Root "samples\infected"),
            (Join-Path $Root "malwares\infected"),
            (Join-Path $Root "Resultados\Apps-Teste")
        )) { $dirs.Add($d) }
    $benRoot = Join-Path $Root "samples\benign"
    if (Test-Path -LiteralPath $benRoot) {
        foreach ($sub in @(Get-ChildItem -LiteralPath $benRoot -Directory -ErrorAction SilentlyContinue)) {
            $dirs.Add($sub.FullName)
        }
    }
    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        foreach ($n in $names) {
            $p = Join-Path $d $n
            if (Test-Path -LiteralPath $p -PathType Leaf) { return (Resolve-Path -LiteralPath $p).Path }
        }
    }
    return $null
}

function Copy-IfDifferent([string]$From, [string]$To) {
    $fromFull = [IO.Path]::GetFullPath($From)
    $toFull = [IO.Path]::GetFullPath($To)
    if ($fromFull -eq $toFull) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $To) | Out-Null
    Copy-Item -LiteralPath $From -Destination $To -Force
}

function Invoke-V12 {
    param([string]$Phase,[string]$Id,[string]$Mode,[string]$Sha,[string[]]$AppArgList,[string[]]$Inputs,[int]$Window)
    $splat = @{
        Phase = $Phase
        Mode = $Mode
        SampleId = $Id
        Sha256 = $Sha
        RepoRoot = $RepoRoot
        OutDir = $OutDir
        WindowSec = $Window
        ExpectedDllSha256 = $ExpectedDllSha256
    }
    if (@($AppArgList).Count -gt 0) { $splat.ApplicationArguments = @($AppArgList) }
    if (@($Inputs).Count -gt 0) { $splat.InputFiles = @($Inputs) }
    Write-Host ("NEXT restore tomware_go AFTER copying {0}" -f $OutDir)
    Write-Host ("app_args={0}" -f (($AppArgList | ForEach-Object { $_ }) -join " | "))
    & $runner @splat
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$payload = Join-Path $OutDir "payload.bin"
$stageDir = Join-Path $RepoRoot "samples\benign"
$appsDir = Join-Path $RepoRoot "Resultados\Apps-Teste"

if ($Job -eq "Prepare") {
    Assert-Dll $RepoRoot $ExpectedDllSha256
    $bytes = [Text.Encoding]::ASCII.GetBytes("JCVHT-CTRL-PE-payload-v1`n")
    $pad = New-Object byte[] 256
    for ($i = 0; $i -lt 256; $i++) { $pad[$i] = 0xA5 }
    [IO.File]::WriteAllBytes($payload, ($bytes + $pad))
    $payloadHash = (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash
    Set-Content -LiteralPath (Join-Path $OutDir "payload.sha256") -Value $payloadHash -Encoding ASCII
    Write-Host ("payload SHA-256 {0}" -f $payloadHash)
    Write-Host ("expected WORK output hash == payload hash")

    $exeCandidates = @(
        (Join-Path $appsDir "TestRecoverWork.exe"),
        (Join-Path $PSScriptRoot "TestRecoverWork.exe"),
        (Join-Path $OutDir "TestRecoverWork.exe")
    )
    $exe = $exeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $exe) { throw "TestRecoverWork.exe missing. Compile first (Compile-TestRecoverWork.ps1) and copy the exe to the VM." }
    $exeHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
    New-Item -ItemType Directory -Force -Path $stageDir, $appsDir | Out-Null
    $staged = Join-Path $stageDir ($exeHash + ".exe")
    Copy-IfDifferent $exe $staged
    Copy-IfDifferent $exe (Join-Path $appsDir "TestRecoverWork.exe")
    Set-Content -LiteralPath (Join-Path $OutDir "ctrl_pe.sha256") -Value $exeHash -Encoding ASCII
    Write-Host ("CTRL_PE staged {0}" -f $staged)

    Write-Host "---- progress samples (must exist) ----"
    $missing = 0
    foreach ($k in $Progress.Keys) {
        $p = Find-HashExe $Progress[$k] $RepoRoot
        if (-not $p) { Write-Host ("MISSING {0} {1}" -f $k, $Progress[$k]); $missing++; continue }
        $stagedBen = Join-Path $stageDir ($Progress[$k] + ".exe")
        Copy-IfDifferent $p $stagedBen
        Write-Host ("OK {0} {1}" -f $k, $stagedBen)
    }
    if ($missing -gt 0) { Write-Host "Copy the five SHA-named benign PEs into samples\benign (or samples\benign\JCVHT_PROG5_BENIGN) before PROG." }
    Write-Host "---- next (restore tomware_go before each arm after Prepare's first CTRL) ----"
    Write-Host ".\Run-CtrlProgress.ps1 -Job CTRL -Mode Native"
    Write-Host "copy OutDir to host, restore tomware_go, re-run Prepare if the exe/payload vanished, then TMW0, then DP"
    Write-Host "Then PROG Native and TMW0 for BEN_17F1 BEN_38A1 BEN_6ED8 BEN_78BA BEN_8F9B"
    Write-Host "CTRL is a controlled demonstrator. identified stays false in the v12 runner."
    return
}

Assert-Dll $RepoRoot $ExpectedDllSha256

if ($Job -eq "CTRL") {
    if ($Mode -notin @("Native", "TMW0", "DP")) { throw "CTRL modes: Native, TMW0, DP" }
    $shaFile = Join-Path $OutDir "ctrl_pe.sha256"
    if (-not (Test-Path -LiteralPath $shaFile)) { throw "Run -Job Prepare first (same OutDir)." }
    if (-not (Test-Path -LiteralPath $payload)) { throw "payload.bin missing; run Prepare." }
    $sha = (Get-Content -LiteralPath $shaFile -Raw).Trim().ToLowerInvariant()
    if (-not (Find-HashExe $sha $RepoRoot)) { throw "CTRL_PE exe not staged as samples\benign\$sha.exe — re-run Prepare." }
    Invoke-V12 -Phase Capture -Id "CTRL_PE" -Mode $Mode -Sha $sha `
        -AppArgList @($payload, "work.bin") -Inputs @($payload) -Window 30
    return
}

if ($Job -eq "PROG") {
    if ($Mode -eq "DP") { throw "PROG is Native vs TMW0 only (Major 2 milestones). No -dp." }
    if (-not $Progress.Contains($SampleId)) {
        throw ("unknown SampleId {0}; use BEN_17F1 BEN_38A1 BEN_6ED8 BEN_78BA BEN_8F9B" -f $SampleId)
    }
    $sha = $Progress[$SampleId]
    if (-not (Find-HashExe $sha $RepoRoot)) { throw ("benign exe missing for {0} {1}" -f $SampleId, $sha) }
    Invoke-V12 -Phase Capture -Id $SampleId -Mode $Mode -Sha $sha -AppArgList @() -Inputs @() -Window 10
    return
}
