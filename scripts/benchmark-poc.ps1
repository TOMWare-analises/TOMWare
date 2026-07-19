#Requires -Version 5.1
<#
.SYNOPSIS
    Benchmark dos PoCs sinteticos TOMWare (validacao de contramedidas).

.EXAMPLE
    .\scripts\benchmark-poc.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [int]$TimeoutSeconds = 30,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot

. (Join-Path $repoRoot "scripts/lib/TomwareBenchmark.ps1")

$manifest = Get-TomwareManifest -ManifestPath (Join-Path $repoRoot "config/corpus-dbi-log.json")
$pinExe = Join-Path $repoRoot "pin/pin.exe"
$toolDll = Join-Path $repoRoot "x64/$Configuration/TOMWare.dll"

if (-not $OutputDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = Join-Path $repoRoot "Resultados/Avaliacao/poc-$stamp"
}

if (-not (Test-Path $toolDll)) {
    throw "Compile TOMWare ($Configuration|x64): $toolDll"
}

$results = @()

Write-Host "Benchmark PoC - $($manifest.poc_tests.Count) testes" -ForegroundColor Cyan

foreach ($test in $manifest.poc_tests) {
    $samplePath = Join-Path $repoRoot $test.path
    if (-not (Test-Path $samplePath)) {
        $alt = Join-Path $repoRoot (Split-Path $test.path -Leaf)
        if (Test-Path $alt) { $samplePath = $alt }
    }

    if (-not (Test-Path $samplePath)) {
        Write-Host "[SKIP] $($test.name) - executavel nao encontrado: $($test.path)" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            TestId = $test.id
            Name   = $test.name
            Scenario = "missing"
            Outcome  = "error"
            Pass     = $false
            Notes    = "compilar PoC antes (ver Apps-Teste-src)"
        }
        continue
    }

    $baseKnobs = @()
    if ($test.PSObject.Properties.Name -contains 'baseline_knobs') {
        $baseKnobs = @($test.baseline_knobs)
    }

    # Timeout per-teste: o overhead simulado (-go) instrumenta cada instrucao
    # e leva ~37-65s, bem acima do default. Permite override pelo manifesto.
    $testTimeout = $TimeoutSeconds
    if ($test.PSObject.Properties.Name -contains 'timeout_seconds') {
        $testTimeout = [int]$test.timeout_seconds
    }

    $baseline = Invoke-TomwarePinRun `
        -PinExe $pinExe -ToolDll $toolDll -SamplePath $samplePath `
        -Knobs $baseKnobs -TimeoutSeconds $testTimeout -Scenario "pin_baseline"

    $knobs = @($test.knobs) + @("-q")
    if ($test.knobs -contains "-dm") { $knobs += "-sf", "config/signatures.txt" }

    $stealth = Invoke-TomwarePinRun `
        -PinExe $pinExe -ToolDll $toolDll -SamplePath $samplePath `
        -Knobs $knobs -TimeoutSeconds $testTimeout -Scenario "pin_stealth"

    $passBaseline = $false
    $passStealth = $false

    switch ($test.id) {
        "env" {
            # Padrao SBSeg 2025: Resumo + Alerta (baseline) / OK (stealth)
            $passBaseline = $baseline.Stdout -match "Alerta:"
            $passStealth = ($stealth.Stdout -notmatch "Alerta:") -and ($stealth.Stdout -match "OK - nenhuma anomalia")
        }
        "memscan" {
            $passBaseline = $baseline.Stdout -match "Alerta:"
            $passStealth = $stealth.Stdout -notmatch "Alerta:"
        }
        "overhead" {
            $passBaseline = $baseline.Stdout -match "\*+\s*Overhead anomalo|\*\*\* Overhead"
            $passStealth = $stealth.Stdout -match "OK - nenhuma anomalia"
        }
        "antidebug" {
            $passBaseline = $baseline.Stdout -match "Alerta:"
            $passStealth = ($stealth.Stdout -notmatch "Alerta:") -and ($stealth.Stdout -match "OK - nenhuma anomalia")
        }
        "processenum" {
            $passBaseline = $baseline.Stdout -match "Alerta:"
            $passStealth = ($stealth.Stdout -notmatch "Alerta:") -and ($stealth.Stdout -match "OK - nenhuma anomalia")
        }
        default {
            $passBaseline = $baseline.Stdout -notmatch [regex]::Escape($test.success_pattern)
            $passStealth = $stealth.Stdout -match [regex]::Escape($test.success_pattern)
        }
    }

    Write-Host "$($test.name): baseline_pass=$passBaseline stealth_pass=$passStealth"

    foreach ($run in @($baseline, $stealth)) {
        $results += [PSCustomObject]@{
            TestId       = $test.id
            Name         = $test.name
            Scenario     = $run.Scenario
            Outcome      = $run.Outcome
            Seconds      = $run.Seconds
            ExitCode     = $run.ExitCode
            Pass         = if ($run.Scenario -eq "pin_stealth") { $passStealth } else { -not $passBaseline }
            SuccessPattern = $test.success_pattern
            Command      = $run.Command
        }
    }
}

$meta = @{ TotalManifest = $manifest.poc_tests.Count; Scenarios = 2; TimeoutSeconds = $TimeoutSeconds }
$files = Export-TomwareBenchmarkSummary -Rows $results -OutputDir $OutputDir -Metadata $meta

Write-Host ""
Write-Host "Resumo: $($files.Markdown)" -ForegroundColor Green

$passed = ($results | Where-Object { $_.Scenario -eq "pin_stealth" -and $_.Pass -eq $true }).Count
$total = ($results | Where-Object { $_.Scenario -eq "pin_stealth" }).Count
Write-Host "PoCs stealth OK: $passed / $total"
