#Requires -Version 5.1
<#
.SYNOPSIS
  Crash-resistant R2-6 malware fidelity: one SHA per boot, abort shutdown, mirror to Downloads.

.DESCRIPTION
  Use after guest power-off / malware-initiated shutdown kills long campaigns.
  - Starts shutdown-abort watchdog
  - Runs -Resume -SafeMalware -OneSampleThenExit
  - Optionally restores VM snapshot between samples (manual)

.EXAMPLE
  cd C:\TOMWare
  .\scripts\r2-fidelity-safe-loop.ps1 -Mode Subset66
  .\scripts\r2-fidelity-safe-loop.ps1 -Mode Expanded
#>
[CmdletBinding()]
param(
    [ValidateSet("Subset66", "Expanded")]
    [string]$Mode = "Expanded",
    [int]$TimeoutSeconds = 60,
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $RepoRoot

Write-Host @"

=== R2-6 SAFE malware fidelity ===
Mode=$Mode Timeout=$TimeoutSeconds
Checklist:
  1) Shared folder tomware_r2 montada (\\vmware-host\Shared Folders\tomware_r2)
  2) Snapshot limpo pre-r2-fidelity-safe
  3) Rede guest OFF
  4) Re-run this after each sample / reboot until all SHA are 5/5
  5) SkewMask N=30 ja completo - nao re-rodar

"@ -ForegroundColor Cyan

# Abort any pending shutdown before start
try { & shutdown.exe /a 2>$null | Out-Null } catch {}

$common = @{
    RepoRoot        = $RepoRoot
    Resume          = $true
    SafeMalware     = $true
    OneSampleThenExit = $true
    TimeoutSeconds  = $TimeoutSeconds
}

if ($Mode -eq "Subset66") {
    & (Join-Path $RepoRoot "scripts\r2-behavioral-fidelity.ps1") @common `
        -MalwareOnly -OnlySha8 "66ebbc7d"
}
else {
    & (Join-Path $RepoRoot "scripts\r2-behavioral-fidelity.ps1") @common `
        -AllInfected -SkipBenign
}

Write-Host @"

Done one sample (or skip). CSV mirrored under %USERPROFILE%\Downloads\behavioral_fidelity*
If guest is still healthy: re-run THIS script immediately for the next SHA.
If guest died: restore snapshot, copy CSV back from Downloads into
  C:\TOMWare\Resultados\evidencias_VM_R2\<folder>\fidelity_results.csv
then re-run.

"@ -ForegroundColor Green
