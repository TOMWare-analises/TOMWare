#Requires -Version 5.1
<#
.SYNOPSIS
    Benchmark automatizado TOMWare sobre amostras do DBI-Log-Corpus (Fase 4).

.EXAMPLE
    .\scripts\benchmark-corpus.ps1 -SamplesDir C:\Samples\MalwareBazaar -TimeoutSeconds 120

.EXAMPLE
    .\scripts\benchmark-corpus.ps1 -SamplesDir C:\Samples -MaxSamples 3 -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SamplesDir,

    [string]$OutputDir = "",
    [string]$ManifestPath = "config/corpus-dbi-log.json",
    [string]$DbilogPath = "",

    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [int]$TimeoutSeconds = 120,
    [int]$MaxSamples = 0,
    [switch]$FollowChild,
    [switch]$IncludeNative,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot

. (Join-Path $repoRoot "scripts/lib/TomwareBenchmark.ps1")

$pinExe = Join-Path $repoRoot "pin/pin.exe"
$toolDll = Join-Path $repoRoot "x64/$Configuration/TOMWare.dll"
$manifest = Get-TomwareManifest -ManifestPath (Join-Path $repoRoot $ManifestPath)

if (-not $OutputDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = Join-Path $repoRoot "Resultados/Avaliacao/corpus-$stamp"
}

if (-not (Test-Path $SamplesDir)) {
    throw "SamplesDir nao encontrado: $SamplesDir"
}
if (-not $DryRun -and -not (Test-Path $toolDll)) {
    throw "Compile TOMWare ($Configuration|x64) antes do benchmark: $toolDll"
}

$results = @()
$sampleList = @($manifest.samples)
if ($MaxSamples -gt 0) {
    $sampleList = $sampleList | Select-Object -First $MaxSamples
}

Write-Host "Benchmark corpus: $($sampleList.Count) amostras" -ForegroundColor Cyan
Write-Host "Saida: $OutputDir"

foreach ($entry in $sampleList) {
    $sha = $entry.sha256
    $samplePath = Resolve-SamplePath -SamplesDir $SamplesDir -Sha256 $sha
    $sampleFound = [bool]$samplePath

    Write-Host ""
    Write-Host "[$sha] found=$sampleFound" -ForegroundColor Yellow

    if (-not $sampleFound) {
        $results += [PSCustomObject]@{
            Sha256       = $sha
            Family       = $entry.family
            Heuristics   = ($entry.heuristics -join "; ")
            TomwareKnobs = ($entry.tomware_knobs -join " ")
            SampleFound  = $false
            Scenario     = "missing"
            Outcome      = "error"
            Seconds      = 0
            ExitCode     = -1
            Improved     = $false
            ImproveReason = "amostra ausente"
            Command      = ""
        }
        continue
    }

    $scenarios = @(
        @{ Name = "pin_baseline"; Knobs = @() }
        @{ Name = "pin_tomware_da"; Knobs = @("-da", "-q", "-sf", "config/signatures.txt") }
    )

    if ($FollowChild) { /* handled in invoke */ }

    $runs = @{}
    foreach ($sc in $scenarios) {
        if ($DryRun) {
            Write-Host "  [dry-run] $($sc.Name)"
            continue
        }

        $run = Invoke-TomwarePinRun `
            -PinExe $pinExe `
            -ToolDll $toolDll `
            -SamplePath $samplePath `
            -Knobs $sc.Knobs `
            -FollowChild:$FollowChild `
            -TimeoutSeconds $TimeoutSeconds `
            -Scenario $sc.Name

        $runs[$sc.Name] = $run
        Write-Host "  $($sc.Name): outcome=$($run.Outcome) sec=$($run.Seconds) exit=$($run.ExitCode)"

        $logDir = Join-Path $OutputDir "logs/$sha"
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $run | Select-Object Scenario, Outcome, Seconds, ExitCode, Command | ConvertTo-Json | Set-Content (Join-Path $logDir "$($sc.Name).json")
    }

    if ($IncludeNative -and -not $DryRun) {
        $native = Invoke-TomwareNativeRun -SamplePath $samplePath -TimeoutSeconds $TimeoutSeconds -Scenario "native"
        $runs["native"] = $native
    }

    if (-not $DryRun) {
        $cmp = Compare-TomwareRuns -BaselineRun $runs["pin_baseline"] -StealthRun $runs["pin_tomware_da"]

        foreach ($sc in $scenarios) {
            $run = $runs[$sc.Name]
            $results += [PSCustomObject]@{
                Sha256        = $sha
                Family        = $entry.family
                Heuristics    = ($entry.heuristics -join "; ")
                TomwareKnobs  = ($entry.tomware_knobs -join " ")
                SampleFound   = $true
                Scenario      = $run.Scenario
                Outcome       = $run.Outcome
                Seconds       = $run.Seconds
                ExitCode      = $run.ExitCode
                Improved      = ($sc.Name -eq "pin_tomware_da" -and $cmp.Improved)
                ImproveReason = if ($sc.Name -eq "pin_tomware_da") { $cmp.Reason } else { "" }
                Command       = $run.Command
            }
        }
    }
}

if (-not $DryRun) {
    $meta = @{
        TotalManifest  = $manifest.samples.Count
        Scenarios      = 2
        TimeoutSeconds = $TimeoutSeconds
        Configuration  = $Configuration
        SamplesDir     = $SamplesDir
    }
    $files = Export-TomwareBenchmarkSummary -Rows $results -OutputDir $OutputDir -Metadata $meta
    Write-Host ""
    Write-Host "Resumo exportado:" -ForegroundColor Green
    Write-Host "  $($files.Csv)"
    Write-Host "  $($files.Markdown)"
}

Write-Host "Concluido."
