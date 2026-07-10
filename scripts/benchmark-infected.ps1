#Requires -Version 5.1
<#
.SYNOPSIS
    Benchmark TOMWare sobre TODOS os .exe de uma pasta (ex.: malwares\infected).

    Diferente de benchmark-corpus.ps1, NAO exige nomes do manifesto DBI-Log.
    Usa o nome do arquivo (hash SHA256) como identificador.

.EXAMPLE
    cd C:\TOMWare
    .\scripts\benchmark-infected.ps1 -SamplesDir C:\TOMWare\malwares\infected -FollowChild
#>
[CmdletBinding()]
param(
    [string]$SamplesDir = "C:\TOMWare\malwares\infected",
    [string]$OutputDir = "",

    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [int]$TimeoutSeconds = 120,
    [int]$MaxSamples = 0,
    [switch]$FollowChild,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot

. (Join-Path $repoRoot "scripts/lib/TomwareBenchmark.ps1")

$pinExe = Join-Path $repoRoot "pin/pin.exe"
$toolDll = Join-Path $repoRoot "x64/$Configuration/TOMWare.dll"

if (-not $OutputDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = Join-Path $repoRoot "Resultados/Avaliacao/infected-$stamp"
}

if (-not (Test-Path $SamplesDir)) {
    throw "Pasta nao encontrada: $SamplesDir"
}
if (-not $DryRun -and -not (Test-Path $toolDll)) {
    throw "Compile TOMWare ($Configuration|x64): $toolDll"
}

$exes = @(Get-ChildItem -Path $SamplesDir -File -Filter *.exe -ErrorAction SilentlyContinue)
if ($MaxSamples -gt 0) {
    $exes = @($exes | Select-Object -First $MaxSamples)
}

Write-Host "Benchmark infected: $($exes.Count) executaveis em $SamplesDir" -ForegroundColor Cyan
Write-Host "Saida: $OutputDir"

if ($exes.Count -eq 0) {
    throw "Nenhum .exe em $SamplesDir"
}

$results = @()

foreach ($exe in $exes) {
    $sampleId = $exe.BaseName
    $samplePath = $exe.FullName

    Write-Host ""
    Write-Host "[$sampleId]" -ForegroundColor Yellow
    Write-Host "  arquivo: $($exe.Name) ($([math]::Round($exe.Length/1MB,2)) MB)"

    if ($DryRun) {
        Write-Host "  [dry-run] pin_baseline + pin_tomware_da"
        continue
    }

    $scenarios = @(
        @{ Name = "pin_baseline"; Knobs = @() }
        @{ Name = "pin_tomware_da"; Knobs = @("-da", "-q", "-sf", "config/signatures.txt") }
    )

    $runs = @{}
    foreach ($sc in $scenarios) {
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

        $logDir = Join-Path $OutputDir "logs/$sampleId"
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $run | Select-Object Scenario, Outcome, Seconds, ExitCode, Command |
            ConvertTo-Json | Set-Content (Join-Path $logDir "$($sc.Name).json")
    }

    $cmp = Compare-TomwareRuns -BaselineRun $runs["pin_baseline"] -StealthRun $runs["pin_tomware_da"]
    $impLabel = if ($cmp.Improved) { "sim" } else { "nao" }
    Write-Host "  Improved: $impLabel ($($cmp.Reason))" -ForegroundColor $(if ($cmp.Improved) { "Green" } else { "Gray" })

    foreach ($sc in $scenarios) {
        $run = $runs[$sc.Name]
        $results += [PSCustomObject]@{
            Sha256        = $sampleId
            SampleId      = $sampleId
            FileName      = $exe.Name
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

if (-not $DryRun) {
    $meta = @{
        TotalManifest = $exes.Count
        Scenarios     = 2
        TimeoutSeconds = $TimeoutSeconds
        Configuration = $Configuration
        SamplesDir    = $SamplesDir
        Mode          = "infected-folder"
    }
    $files = Export-TomwareBenchmarkSummary -Rows $results -OutputDir $OutputDir -Metadata $meta

    $improved = ($results | Where-Object { $_.Improved -eq $true }).Count
    $total = ($results | Where-Object { $_.Scenario -eq "pin_tomware_da" }).Count

    Write-Host ""
    Write-Host "Resumo exportado:" -ForegroundColor Green
    Write-Host "  $($files.Csv)"
    Write-Host "  $($files.Markdown)"
    Write-Host "Melhoria (Improved=sim): $improved / $total"
}

Write-Host "Concluido."
