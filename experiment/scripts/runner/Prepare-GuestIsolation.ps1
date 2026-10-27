#Requires -Version 5.1
<#
.SYNOPSIS
  Preparacao unica do snapshot limpo da VM (executar ANTES de tirar o snapshot tomware_ready).
  Nao substitui revert de snapshot: apenas reduz shutdown, hibernacao e rede externa.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\TOMWare"
)

$ErrorActionPreference = "Continue"

Write-Host "=== Prepare-GuestIsolation ===" -ForegroundColor Cyan

# 1. Nao hibernar / nao dormir
try { powercfg -h off | Out-Null } catch {}
try { powercfg /change monitor-timeout-ac 0 | Out-Null } catch {}
try { powercfg /change standby-timeout-ac 0 | Out-Null } catch {}
try { powercfg /change hibernate-timeout-ac 0 | Out-Null } catch {}
try { powercfg /change monitor-timeout-dc 0 | Out-Null } catch {}
try { powercfg /change standby-timeout-dc 0 | Out-Null } catch {}

# 2. Defender: exclusao da arvore TOMWare (senao apaga amostras a meio)
try {
    Add-MpPreference -ExclusionPath $RepoRoot -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath (Join-Path $RepoRoot "malwares") -ErrorAction SilentlyContinue
    Write-Host "Defender exclusions OK" -ForegroundColor Green
} catch {
    Write-Host "Defender exclusions falharam (ok se Defender estiver off)" -ForegroundColor Yellow
}

# 3. Impedir shutdown.exe via Image File Execution Options (watchdog extra)
$ifeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\shutdown.exe"
try {
    New-Item -Path $ifeo -Force | Out-Null
    New-ItemProperty -Path $ifeo -Name Debugger -Value "systray.exe" -PropertyType String -Force | Out-Null
    Write-Host "IFEO shutdown.exe OK" -ForegroundColor Green
} catch {
    Write-Host "IFEO shutdown.exe falhou (precisa Admin)" -ForegroundColor Yellow
}

# 4. Watchdog de shutdown /a como tarefa independente do PowerShell da campanha
$wdDir = Join-Path $RepoRoot "experiment\scripts\runner"
$wdPath = Join-Path $wdDir "ShutdownAbortWatchdog.ps1"
@'
while ($true) {
  try { & shutdown.exe /a 2>$null | Out-Null } catch {}
  Start-Sleep -Seconds 2
}
'@ | Set-Content -Path $wdPath -Encoding ASCII

schtasks /Create /TN "TOMWareShutdownAbort" /SC ONSTART /RU SYSTEM /RL HIGHEST /F /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$wdPath`"" | Out-Null
try { schtasks /Run /TN "TOMWareShutdownAbort" | Out-Null } catch {}

# 5. Desligar adaptadores de rede do convidado (VMware Tools / Guest Additions continuam a funcionar)
Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host ("NIC disabled: " + $_.Name) -ForegroundColor Yellow
    } catch {}
}

# 6. Nao entrar em Automatic Repair apos power-off (o snapshot e crash-consistent)
try {
    bcdedit /set `{default`} recoveryenabled No | Out-Null
    bcdedit /set `{default`} bootstatuspolicy IgnoreAllFailures | Out-Null
    Write-Host "BCD: recoverydisabled + IgnoreAllFailures OK" -ForegroundColor Green
} catch {
    Write-Host "BCD boot policy falhou (precisa Admin)" -ForegroundColor Yellow
}

# 7. Windows Update e popups
try { Stop-Service wuauserv -Force -ErrorAction SilentlyContinue } catch {}
try { Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
try {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Value 1 -PropertyType DWord -Force | Out-Null
} catch {}

Write-Host "`nGuest isolation aplicada." -ForegroundColor Green
Write-Host "PROXIMO PASSO: tire um snapshot VMware/VBox chamado tomware_ready COM a pasta C:\TOMWare ja copiada e as amostras extraidas." -ForegroundColor Cyan
Write-Host "A campanha completa DEVE ser orquestrada no HOST (Run-HostCampaign.ps1), nao nesta janela." -ForegroundColor Cyan
