#!/usr/bin/env powershell
#Requires -Version 5.1
<#
.SYNOPSIS
  Reviewer 2 - baseline ladder: native, pin-only/noop, disabled TOMWare, enabled modules, -da.

.DESCRIPTION
  Runs oracles (and optionally corpus SHA list) across ladder levels.
  Pin-only: Pin with -t pointing at a minimal empty tool if present; otherwise
  documents pin+TOMWare with no defend knobs as "disabled-module" baseline.

.EXAMPLE
  .\scripts\r2-baseline-ladder.ps1 -Mode oracles
#>
[CmdletBinding()]
param(
    [ValidateSet("oracles", "corpus", "both")]
    [string]$Mode = "oracles",
    [string]$RepoRoot = "",
    [string]$OutDir = "",
    [int]$TimeoutSeconds = 30,
    [int]$Repeat = 3
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $RepoRoot
. (Join-Path $RepoRoot "scripts/lib/TomwareBenchmark.ps1")

$pinExe = Join-Path $RepoRoot "pin/pin.exe"
$toolDll = Join-Path $RepoRoot "x64/Release/TOMWare.dll"
$apps = Join-Path $RepoRoot "Resultados/Apps-Teste"
if (-not $OutDir) {
    $OutDir = Join-Path $RepoRoot "Resultados\evidencias_VM_R2\baseline_ladder"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Prefer Pin empty tool from SDK if present
$emptyToolCandidates = @(
    (Join-Path $RepoRoot "pin/source/tools/ManualExamples/obj-intel64/inscount0.dll"),
    (Join-Path $RepoRoot "pin/source/tools/ManualExamples/obj-intel64/inscount0.so"),
    (Join-Path $RepoRoot "x64/Release/EmptyPinTool.dll")
)
$emptyTool = $null
foreach ($c in $emptyToolCandidates) {
    if (Test-Path $c) { $emptyTool = $c; break }
}

$oracles = @(
    @{ Name = "TestAntiDebug"; Path = Join-Path $apps "TestAntiDebug.exe"; EnableKnobs = @("-dd", "-q"); Stimulus = @("-gdb", "-q") }
    @{ Name = "TestOverhead"; Path = Join-Path $apps "TestOverhead.exe"; EnableKnobs = @("-do", "-q"); Stimulus = @("-go", "-q") }
    @{ Name = "TestProcessEnum"; Path = Join-Path $apps "TestProcessEnum.exe"; EnableKnobs = @("-dp", "-q"); Stimulus = @("-q") }
)

function Invoke-PinWithTool {
    param($Tool, $Sample, [string[]]$Knobs, $Scenario, $Label)
    if (-not $Tool) {
        return [PSCustomObject]@{
            Scenario = $Scenario; Outcome = "skipped"; Seconds = 0; ExitCode = -1
            Stdout = ""; Stderr = "tool missing"; PeakWorkingSetMB = $null
        }
    }
    return Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $Tool -SamplePath $Sample `
        -Knobs $Knobs -TimeoutSeconds $TimeoutSeconds -Scenario $Scenario -ProgressLabel $Label
}

$results = @()

if ($Mode -eq "oracles" -or $Mode -eq "both") {
    foreach ($o in $oracles) {
        if (-not (Test-Path $o.Path)) {
            Write-Host "skip missing oracle $($o.Name)" -ForegroundColor Yellow
            continue
        }
        for ($r = 1; $r -le $Repeat; $r++) {
            Write-Host "=== $($o.Name) rep $r/$Repeat ===" -ForegroundColor Cyan

            # 1) Native
            $native = Invoke-TomwareNativeRun -SamplePath $o.Path -TimeoutSeconds $TimeoutSeconds -Scenario "native_$($o.Name)_$r"
            $results += [PSCustomObject]@{
                Target = $o.Name; Rep = $r; Level = "native"; Knobs = ""
                Outcome = $native.Outcome; Seconds = $native.Seconds; ExitCode = $native.ExitCode
                PeakWorkingSetMB = $null; Note = "no Pin"
            }

            # 2) Pin + empty/noop tool (if available)
            if ($emptyTool) {
                $pinOnly = Invoke-PinWithTool -Tool $emptyTool -Sample $o.Path -Knobs @() `
                    -Scenario "pin_empty_$($o.Name)_$r" -Label "pin-empty-$r"
                $results += [PSCustomObject]@{
                    Target = $o.Name; Rep = $r; Level = "pin_empty_tool"; Knobs = ""
                    Outcome = $pinOnly.Outcome; Seconds = $pinOnly.Seconds; ExitCode = $pinOnly.ExitCode
                    PeakWorkingSetMB = if ($pinOnly.PSObject.Properties.Name -contains "PeakWorkingSetMB") { $pinOnly.PeakWorkingSetMB } else { $null }
                    Note = "empty/noop pintool: $emptyTool"
                }
            } else {
                $results += [PSCustomObject]@{
                    Target = $o.Name; Rep = $r; Level = "pin_empty_tool"; Knobs = ""
                    Outcome = "unavailable"; Seconds = 0; ExitCode = -1
                    PeakWorkingSetMB = $null
                    Note = "no empty pintool DLL built; see PROTOCOL.md"
                }
            }

            # 3) Pin + TOMWare disabled (no defend knobs) - with stimulus when needed
            $disKnobs = @("-q") + @($o.Stimulus | Where-Object { $_ -ne "-q" })
            $disKnobs = @($disKnobs | Select-Object -Unique)
            $disabled = Invoke-PinWithTool -Tool $toolDll -Sample $o.Path -Knobs $disKnobs `
                -Scenario "disabled_$($o.Name)_$r" -Label "disabled-$r"
            $results += [PSCustomObject]@{
                Target = $o.Name; Rep = $r; Level = "tomware_disabled"; Knobs = ($disKnobs -join " ")
                Outcome = $disabled.Outcome; Seconds = $disabled.Seconds; ExitCode = $disabled.ExitCode
                PeakWorkingSetMB = $null; Note = "TOMWare loaded; defense modules off (stimulus retained if any)"
            }

            # 4) Enabled module (matched stimulus + countermeasure)
            $enKnobs = @($o.Stimulus) + @($o.EnableKnobs) | Select-Object -Unique
            # ensure -q once
            if ($enKnobs -notcontains "-q") { $enKnobs += "-q" }
            $enabled = Invoke-PinWithTool -Tool $toolDll -Sample $o.Path -Knobs $enKnobs `
                -Scenario "enabled_$($o.Name)_$r" -Label "enabled-$r"
            $results += [PSCustomObject]@{
                Target = $o.Name; Rep = $r; Level = "tomware_enabled"; Knobs = ($enKnobs -join " ")
                Outcome = $enabled.Outcome; Seconds = $enabled.Seconds; ExitCode = $enabled.ExitCode
                PeakWorkingSetMB = $null; Note = "module countermeasure on"
            }

            # 5) Combined -da (with stimulus for AntiDebug/Overhead)
            $daKnobs = @("-da", "-q")
            if ($o.Name -eq "TestAntiDebug") { $daKnobs = @("-gdb", "-da", "-q") }
            if ($o.Name -eq "TestOverhead") { $daKnobs = @("-go", "-da", "-q") }
            $da = Invoke-PinWithTool -Tool $toolDll -Sample $o.Path -Knobs $daKnobs `
                -Scenario "da_$($o.Name)_$r" -Label "da-$r"
            $results += [PSCustomObject]@{
                Target = $o.Name; Rep = $r; Level = "tomware_da"; Knobs = ($daKnobs -join " ")
                Outcome = $da.Outcome; Seconds = $da.Seconds; ExitCode = $da.ExitCode
                PeakWorkingSetMB = $null; Note = "all modules (-da)"
            }
        }
    }
}

if ($Mode -eq "corpus" -or $Mode -eq "both") {
    $benRoot = Join-Path $RepoRoot "Resultados/evidencias_VM/benign"
    $malRoot = Join-Path $RepoRoot "Resultados/evidencias_VM/malign"
    $sampleDirs = @()
    if (Test-Path $benRoot) { $sampleDirs += Get-ChildItem $benRoot -Directory }
    if (Test-Path $malRoot) { $sampleDirs += Get-ChildItem $malRoot -Directory }
    $shaListPath = Join-Path $OutDir "corpus_targets.txt"
    $targets = @()
    foreach ($d in $sampleDirs) {
        $sha = $d.Name
        # Prefer exe under malwares if present
        $candidates = @(
            (Join-Path $RepoRoot "malwares/benign/$sha.exe"),
            (Join-Path $RepoRoot "malwares/infected/$sha.exe"),
            (Join-Path $RepoRoot "malwares/$sha.exe")
        )
        $exe = $null
        foreach ($c in $candidates) { if (Test-Path $c) { $exe = $c; break } }
        if (-not $exe) {
            $targets += "$sha`tMISSING"
            continue
        }
        $targets += "$sha`t$exe"
        foreach ($level in @(
            @{ L = "native"; Tool = $null; Knobs = @() },
            @{ L = "tomware_disabled"; Tool = $toolDll; Knobs = @("-q") },
            @{ L = "tomware_do"; Tool = $toolDll; Knobs = @("-do", "-q") },
            @{ L = "tomware_da"; Tool = $toolDll; Knobs = @("-da", "-q") }
        )) {
            Write-Host "corpus $sha $($level.L)" -ForegroundColor DarkCyan
            if ($level.L -eq "native") {
                $run = Invoke-TomwareNativeRun -SamplePath $exe -TimeoutSeconds $TimeoutSeconds -Scenario "native_$sha"
            } else {
                $run = Invoke-PinWithTool -Tool $level.Tool -Sample $exe -Knobs $level.Knobs `
                    -Scenario "$($level.L)_$sha" -Label $level.L
            }
            $results += [PSCustomObject]@{
                Target = $sha; Rep = 1; Level = $level.L; Knobs = ($level.Knobs -join " ")
                Outcome = $run.Outcome; Seconds = $run.Seconds; ExitCode = $run.ExitCode
                PeakWorkingSetMB = $null; Note = "corpus ladder"
            }
        }
    }
    Set-Content -Path $shaListPath -Value ($targets -join "`n") -Encoding UTF8
}

$csv = Join-Path $OutDir "ladder_results.csv"
$results | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8

$proto = @"
# Baseline ladder protocol (Reviewer 2 item 3)

Levels:
1. native - no Pin
2. pin_empty_tool - Pin + empty/noop pintool (if DLL available); else marked unavailable
3. tomware_disabled - Pin + TOMWare.dll with -q only (plus oracle stimulus -gdb/-go when required)
4. tomware_enabled - Pin + matched stimulus + module knob (-dd/-do/-dp)
5. tomware_da - Pin + -da (combined mode)

Empty tool path tried: $($emptyToolCandidates -join '; ')
Selected empty tool: $(if ($emptyTool) { $emptyTool } else { 'NONE - build EmptyPinTool or ManualExamples inscount0' })
Repeat per oracle: $Repeat
TimeoutSeconds: $TimeoutSeconds
Date: $(Get-Date -Format o)
"@
Set-Content -Path (Join-Path $OutDir "PROTOCOL.md") -Value $proto -Encoding UTF8
Write-Host "Wrote $csv ($($results.Count) rows)" -ForegroundColor Green
