#Requires -Version 5.1
<#
.SYNOPSIS
    Executa UMA amostra: baseline + cada contramedida (-de..-dp) + -da.
    Usa Invoke-TomwarePinRun (mesmo metodo do benchmark-infected.ps1).

.EXAMPLE
    cd C:\TOMWare
    .\scripts\run-one-sample-knobs.ps1 -Sample C:\TOMWare\malwares\infected\36685efc....exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Sample = "",

    [int]$TimeoutSeconds = 120,
    [bool]$FollowChild = $true,

    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot
. (Join-Path $repoRoot "scripts/lib/TomwareBenchmark.ps1")

$pinExe = Join-Path $repoRoot "pin/pin.exe"
$toolDll = Join-Path $repoRoot "x64/$Configuration/TOMWare.dll"

if (-not $Sample) {
    $Sample = (Get-ChildItem "C:\TOMWare\malwares\infected\36685efc*.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName)
}
if (-not $Sample -or -not (Test-Path $Sample)) {
    throw "Defina -Sample ou coloque a amostra em malwares\infected\"
}
if (-not (Test-Path $toolDll)) {
    throw "TOMWare.dll nao encontrada: $toolDll"
}

$scenarios = @(
    @{ Nome = "baseline (TOMWare sem CM)"; Knobs = @() }
    @{ Nome = "-de (ambiente)";           Knobs = @("-de", "-q") }
    @{ Nome = "-dm (memoria)";            Knobs = @("-dm", "-q", "-sf", "config/signatures.txt") }
    @{ Nome = "-do (timing)";             Knobs = @("-do", "-q") }
    @{ Nome = "-dd (anti-debug)";         Knobs = @("-dd", "-q") }
    @{ Nome = "-dp (processos)";          Knobs = @("-dp", "-q") }
    @{ Nome = "-da (todas)";              Knobs = @("-da", "-q", "-sf", "config/signatures.txt") }
)

Write-Host "Amostra: $Sample" -ForegroundColor Cyan
Write-Host "Timeout: ${TimeoutSeconds}s | Metodo: Invoke-TomwarePinRun (igual benchmark)`n"

$results = @()
foreach ($sc in $scenarios) {
    Write-Host "=== $($sc.Nome) ===" -ForegroundColor Yellow
    $run = Invoke-TomwarePinRun `
        -PinExe $pinExe `
        -ToolDll $toolDll `
        -SamplePath $Sample `
        -Knobs $sc.Knobs `
        -FollowChild:$FollowChild `
        -TimeoutSeconds $TimeoutSeconds `
        -Scenario $sc.Nome

    Write-Host "  outcome=$($run.Outcome) sec=$($run.Seconds) exit=$($run.ExitCode)" -ForegroundColor Green
    $results += [PSCustomObject]@{
        Cenario  = $sc.Nome
        Outcome  = $run.Outcome
        Segundos = $run.Seconds
        Exit     = $run.ExitCode
    }
}

$base = $results[0].Segundos
Write-Host "`n=== COMPARATIVO (baseline = ${base}s) ===" -ForegroundColor Cyan
$results | ForEach-Object {
    [PSCustomObject]@{
        Cenario         = $_.Cenario
        Outcome         = $_.Outcome
        Segundos        = $_.Segundos
        DeltaVsBaseline = [math]::Round($_.Segundos - $base, 2)
        Exit            = $_.Exit
    }
} | Format-Table -AutoSize

$da = $results | Where-Object { $_.Cenario -like "-da*" } | Select-Object -First 1
if ($da.Segundos -gt ($base * 1.25) -and $base -lt $TimeoutSeconds) {
    Write-Host "Conclusao: -da prolongou execucao vs baseline (+$([math]::Round($da.Segundos - $base, 1))s)" -ForegroundColor Green
}
else {
    Write-Host "Conclusao: nesta execucao, nenhum cenario prolongou claramente vs baseline." -ForegroundColor Yellow
    Write-Host "Compare Outcome/Seconds - overhead de -do/-da pode aumentar tempo mesmo sem deteccao evitada." -ForegroundColor DarkGray
}
