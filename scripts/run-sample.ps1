#Requires -Version 5.1
<#
.SYNOPSIS
    Executa uma amostra sob Intel Pin com a pintool TOMWare.

.DESCRIPTION
    Wrapper para execucao padronizada (Fase 1): arquitetura x64, follow-child
    opcional, contramedidas configuraveis e modo silencioso.

.EXAMPLE
    .\scripts\run-sample.ps1 -Sample .\Resultados\Apps-Teste\TestGetEnvironments.exe -DefendAll

.EXAMPLE
    .\scripts\run-sample.ps1 -Sample C:\Samples\alvo.exe -DefendAll -Quiet -FollowChild
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Sample,

    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [switch]$DefendAll,
    [switch]$EnvsDefend,
    [switch]$MemoryDefend,
    [switch]$OverheadDefend,
    [switch]$DebugDefend,
    [switch]$ProcessEnumDefend,
    [switch]$SimulateOverhead,
    [switch]$Quiet,
    [switch]$FollowChild,

    [string]$SignatureFile = "config/signatures.txt",

    [uint32]$MaxExceptions = 0,

    [string]$PinExe = ".\pin\pin.exe",
    [string]$ToolDll = ".\x64\$Configuration\TOMWare.dll",

    [int]$TimeoutSeconds = 0
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot

if (-not (Test-Path $PinExe)) {
    throw "pin.exe nao encontrado: $PinExe"
}
if (-not (Test-Path $ToolDll)) {
    throw "TOMWare.dll nao encontrada: $ToolDll (compile em $Configuration|x64)"
}
if (-not (Test-Path $Sample)) {
    throw "Amostra nao encontrada: $Sample"
}

$knobs = @()
if ($DefendAll)       { $knobs += "-da" }
if ($EnvsDefend)      { $knobs += "-de" }
if ($MemoryDefend)    { $knobs += "-dm" }
if ($OverheadDefend)  { $knobs += "-do" }
if ($DebugDefend)     { $knobs += "-dd" }
if ($ProcessEnumDefend) { $knobs += "-dp" }
if ($SimulateOverhead){ $knobs += "-go" }
if ($Quiet)           { $knobs += "-q" }
if ($DefendAll -or $MemoryDefend) {
    if ($SignatureFile) { $knobs += "-sf", $SignatureFile }
}
if ($MaxExceptions -gt 0) { $knobs += "-me", "$MaxExceptions" }

$pinArgs = @()
if ($FollowChild) {
    $pinArgs += "-follow_execv", "1"
}
$pinArgs += "-t", (Resolve-Path $ToolDll).Path
$pinArgs += $knobs
$pinArgs += "--", (Resolve-Path $Sample).Path

Write-Host "Executando: $PinExe $($pinArgs -join ' ')"

if ($TimeoutSeconds -gt 0) {
    $job = Start-Job -ScriptBlock {
        param($Pin, $Args)
        Set-Location $using:repoRoot
        & $Pin @Args
        exit $LASTEXITCODE
    } -ArgumentList (Resolve-Path $PinExe).Path, $pinArgs

    if (-not (Wait-Job $job -Timeout $TimeoutSeconds)) {
        Stop-Job $job -Force
        Remove-Job $job
        throw "Timeout apos ${TimeoutSeconds}s"
    }

    $exitCode = (Receive-Job $job)
    Remove-Job $job
    exit $exitCode
}

& $PinExe @pinArgs
exit $LASTEXITCODE
