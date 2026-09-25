#!/usr/bin/env powershell
#Requires -Version 5.1
<#
.SYNOPSIS
  Reviewer 2 - SkewMask redesign: fixed N=30, retain all timing results, report distributions.

.DESCRIPTION
  Runs TestOverhead.exe under Pin:
    B: -go -q          (N times, no discarding)
    C: -go -do -q      (N times, no discarding)
  Parses ticks from console output; writes CSV + SUMMARY + JSON stats.

.EXAMPLE
  .\scripts\r2-skewmask-fixedN.ps1 -N 30
#>
[CmdletBinding()]
param(
    [int]$N = 30,
    [string]$RepoRoot = "",
    [string]$OutDir = "",
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $RepoRoot

. (Join-Path $RepoRoot "scripts/lib/TomwareBenchmark.ps1")

$pinExe = Join-Path $RepoRoot "pin/pin.exe"
$toolDll = Join-Path $RepoRoot "x64/Release/TOMWare.dll"
$oracle = Join-Path $RepoRoot "Resultados/Apps-Teste/TestOverhead.exe"
if (-not $OutDir) {
    $OutDir = Join-Path (Split-Path -Parent $RepoRoot) "evidencias_VM/skewmask_redesign_N$N"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not (Test-Path $pinExe)) { throw "pin.exe missing: $pinExe" }
if (-not (Test-Path $toolDll)) { throw "TOMWare.dll missing: $toolDll" }
if (-not (Test-Path $oracle)) { throw "TestOverhead.exe missing: $oracle" }

function Get-TicksFromText([string]$text) {
    if ($text -match 'Ticks\s*\+\s*Lat[eê]ncia:\s*([0-9]+(?:[.,][0-9]+)?)') {
        return [double]($Matches[1] -replace ',', '.')
    }
    if ($text -match '([0-9]+(?:[.,][0-9]+)?)\s*,\s*Limite:\s*3000') {
        return [double]($Matches[1] -replace ',', '.')
    }
    return $null
}

function Test-Anomaly([string]$text) {
    return ($text -match 'anomalo|an[oô]malo|possivel DBI|possível DBI')
}

function Test-Ok([string]$text) {
    return ($text -match 'OK\s*-\s*nenhuma anomalia|OK --- no anomaly|nenhuma anomalia')
}

$rows = @()
$conditions = @(
    @{ Name = "B"; Knobs = @("-go", "-q"); Expect = "anomaly" }
    @{ Name = "C"; Knobs = @("-go", "-do", "-q"); Expect = "ok" }
)

foreach ($cond in $conditions) {
    for ($i = 1; $i -le $N; $i++) {
        Write-Host ("[{0}] run {1}/{2} knobs={3}" -f $cond.Name, $i, $N, ($cond.Knobs -join " ")) -ForegroundColor Cyan
        $run = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $toolDll -SamplePath $oracle `
            -Knobs $cond.Knobs -TimeoutSeconds $TimeoutSeconds `
            -Scenario ("skew_{0}_{1}" -f $cond.Name, $i) -ProgressLabel ("{0}-{1}" -f $cond.Name, $i)
        $text = "{0}`n{1}" -f $run.Stdout, $run.Stderr
        $logPath = Join-Path $OutDir ("{0}_go{1}_run{2}.txt" -f $cond.Name, $(if ($cond.Name -eq "C") { "_do" } else { "" }), $i)
        # normalize names: B_go_runN / C_go_do_runN
        if ($cond.Name -eq "B") {
            $logPath = Join-Path $OutDir ("B_go_run{0}.txt" -f $i)
        } else {
            $logPath = Join-Path $OutDir ("C_go_do_run{0}.txt" -f $i)
        }
        Set-Content -Path $logPath -Value $text -Encoding UTF8
        $ticks = Get-TicksFromText $text
        $anom = Test-Anomaly $text
        $ok = Test-Ok $text
        $rows += [PSCustomObject]@{
            Condition = $cond.Name
            Run = $i
            Knobs = ($cond.Knobs -join " ")
            Ticks = $ticks
            Anomaly = [bool]$anom
            Ok = [bool]$ok
            Outcome = $run.Outcome
            Seconds = $run.Seconds
            ExitCode = $run.ExitCode
            Log = (Split-Path -Leaf $logPath)
        }
        Write-Host ("    ticks={0} anomaly={1} ok={2} outcome={3}" -f $ticks, $anom, $ok, $run.Outcome)
    }
}

$csvPath = Join-Path $OutDir "ticks_all.csv"
$rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$b = @($rows | Where-Object { $_.Condition -eq "B" })
$c = @($rows | Where-Object { $_.Condition -eq "C" })
$bAnom = @($b | Where-Object { $_.Anomaly -or ($null -ne $_.Ticks -and $_.Ticks -gt 3000) }).Count
$cOk = @($c | Where-Object { $_.Ok -or ($null -ne $_.Ticks -and $_.Ticks -le 3000 -and -not $_.Anomaly) }).Count

$summary = @"
protocol=fixedN_redesign
N=$N
B_knobs=-go -q
C_knobs=-go -do -q
oracle=TestOverhead.exe
threshold=3000
B_anomaly_hits=$bAnom/$N
C_ok_hits=$cOk/$N
B_ticks=$(($b | ForEach-Object { $_.Ticks }) -join ',')
C_ticks=$(($c | ForEach-Object { $_.Ticks }) -join ',')
retained_all=true
no_discard=true
date=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
host=$env:COMPUTERNAME
"@
Set-Content -Path (Join-Path $OutDir "SUMMARY.txt") -Value $summary -Encoding UTF8
Write-Host $summary -ForegroundColor Green
Write-Host "Wrote $OutDir" -ForegroundColor Green
