#Requires -Version 5.1
<#
.SYNOPSIS
  Host helper: checklist zero-share + (opcional) automacao via vmrun.

.DESCRIPTION
  Fluxo padrao MANUAL (mais seguro, sem share durante malware):
    guest 1 amostra -> voce copia CSV -> restore snapshot -> devolve CSV -> repete

  Se tiver VMware Workstation + vmrun + credenciais do guest, use -UseVmrun.

.EXAMPLE
  # So imprime o roteiro e confere CSV no host
  .\scripts\r2-fidelity-host-queue.ps1 -Mode Expanded

  # Com vmrun (preencha VmxPath / user / senha)
  .\scripts\r2-fidelity-host-queue.ps1 -Mode Expanded -UseVmrun `
    -VmxPath "D:\VMs\Win10-tomware\Win10-tomware.vmx" `
    -SnapshotName "pre-r2-fidelity-safe" `
    -GuestUser "user" -GuestPassword "****"
#>
[CmdletBinding()]
param(
    [ValidateSet("Subset66", "Expanded")]
    [string]$Mode = "Expanded",
    [string]$HostEvidenceRoot = "",
    [switch]$UseVmrun,
    [string]$VmxPath = "",
    [string]$SnapshotName = "pre-r2-fidelity-safe",
    [string]$GuestUser = "",
    [string]$GuestPassword = "",
    [string]$VmrunExe = "",
    [int]$TimeoutSeconds = 60,
    [int]$MaxSamples = 20
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $HostEvidenceRoot) {
    $HostEvidenceRoot = Join-Path (Split-Path -Parent $repo) "evidencias_VM_R2"
}

$tag = if ($Mode -eq "Subset66") { "behavioral_fidelity" } else { "behavioral_fidelity_expanded" }
$hostDir = Join-Path $HostEvidenceRoot $tag
New-Item -ItemType Directory -Force -Path $hostDir | Out-Null
$hostCsv = Join-Path $hostDir "fidelity_results.csv"
$guestCsv = "C:\TOMWare\Resultados\evidencias_VM_R2\$tag\fidelity_results.csv"
$guestScript = "C:\TOMWare\scripts\r2-fidelity-one-sample-noshares.ps1"

function Get-CompleteCount([string]$CsvPath) {
    if (-not (Test-Path $CsvPath)) { return 0 }
    $data = @(Import-Csv $CsvPath)
    $by = @{}
    foreach ($r in $data) {
        $k = ([string]$r.Sha8).ToLowerInvariant()
        if (-not $by.ContainsKey($k)) { $by[$k] = New-Object 'System.Collections.Generic.HashSet[string]' }
        [void]$by[$k].Add([string]$r.Level)
    }
    $need = @("native", "pin_empty", "pin_fidelity", "tomware_disabled", "tomware_do")
    $n = 0
    foreach ($k in $by.Keys) {
        $ok = $true
        foreach ($lv in $need) { if (-not $by[$k].Contains($lv)) { $ok = $false; break } }
        if ($ok) { $n++ }
    }
    return $n
}

$target = if ($Mode -eq "Subset66") { 3 } else { 14 }
$done = Get-CompleteCount $hostCsv

Write-Host @"

============================================================
 R2-6 ZERO-SHARE queue (host)
 Mode=$Mode | complete_on_host=$done / target~$target
 Host CSV: $hostCsv
============================================================

REGRA DE OURO
  Shared Folders = DISABLED enquanto malware roda
  Rede guest = OFF
  Snap = $SnapshotName

CICLO MANUAL (recomendado)
  A) Na VM (ja no snapshot limpo, CSV restaurado se houver):
       cd C:\TOMWare
       .\scripts\r2-fidelity-one-sample-noshares.ps1 -Mode $Mode -TimeoutSeconds $TimeoutSeconds

  B) Quando aparecer READY_FOR_HOST:
       - Arraste SOMENTE fidelity_results.csv da VM para:
         $hostDir\
       - NAO arraste .exe / pastas de amostras

  C) VMware -> Snapshot -> Restore '$SnapshotName'
       (guest volta limpo; share continua off)

  D) Arraste o CSV do host DE VOLTA para:
       $guestCsv
       (crie a pasta se preciso)

  E) Repita A-D ate complete_on_host >= target
     Subset66 alvo: 3 SHA | Expanded alvo: 14 SHA

"@ -ForegroundColor Cyan

if (-not $UseVmrun) {
    Write-Host "Modo manual ativo (sem vmrun). Siga o ciclo acima." -ForegroundColor Green
    Write-Host ("Progresso atual no host: {0} SHA com matriz 5/5" -f $done) -ForegroundColor Yellow
    return
}

function Find-Vmrun {
    param([string]$Hint)
    if ($Hint -and (Test-Path $Hint)) { return $Hint }
    $cands = @(
        "${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmrun.exe",
        "${env:ProgramFiles}\VMware\VMware Workstation\vmrun.exe"
    )
    foreach ($c in $cands) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command vmrun.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "vmrun.exe nao encontrado. Instale VMware Workstation ou use o modo manual."
}

if (-not $VmxPath) { throw "-VmxPath obrigatorio com -UseVmrun" }
if (-not (Test-Path $VmxPath)) { throw "VMX nao encontrado: $VmxPath" }
if (-not $GuestUser -or -not $GuestPassword) { throw "-GuestUser/-GuestPassword obrigatorios com -UseVmrun" }

$vmrun = Find-Vmrun -Hint $VmrunExe
Write-Host "Using vmrun: $vmrun" -ForegroundColor DarkGray

function Invoke-Vmrun([string[]]$Args) {
    & $vmrun @Args
    if ($LASTEXITCODE -ne 0) { throw "vmrun failed ($LASTEXITCODE): $($Args -join ' ')" }
}

for ($i = 1; $i -le $MaxSamples; $i++) {
    $done = Get-CompleteCount $hostCsv
    Write-Host ("--- ciclo {0}/{1} | complete={2} ---" -f $i, $MaxSamples, $done) -ForegroundColor Cyan
    if ($done -ge $target) {
        Write-Host "Fila completa no host ($done/$target)." -ForegroundColor Green
        break
    }

    Write-Host "Revert snapshot + start..." -ForegroundColor DarkGray
    Invoke-Vmrun @("-T", "ws", "revertToSnapshot", $VmxPath, $SnapshotName)
    Invoke-Vmrun @("-T", "ws", "start", $VmxPath, "gui")
    Start-Sleep -Seconds 25

    # Push latest host CSV into guest (resume state)
    if (Test-Path $hostCsv) {
        Write-Host "Push CSV host -> guest..." -ForegroundColor DarkGray
        Invoke-Vmrun @("-T", "ws", "-gu", $GuestUser, "-gp", $GuestPassword,
            "createDirectoryInGuest", $VmxPath, (Split-Path -Parent $guestCsv))
        Invoke-Vmrun @("-T", "ws", "-gu", $GuestUser, "-gp", $GuestPassword,
            "copyFileFromHostToGuest", $VmxPath, $hostCsv, $guestCsv)
    }

    Write-Host "Run one sample in guest (NO share)..." -ForegroundColor DarkGray
    $cmd = "powershell.exe"
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$guestScript`" -Mode $Mode -TimeoutSeconds $TimeoutSeconds"
    Invoke-Vmrun @("-T", "ws", "-gu", $GuestUser, "-gp", $GuestPassword,
        "runProgramInGuest", $VmxPath, $cmd, $args)

    Write-Host "Pull CSV guest -> host..." -ForegroundColor DarkGray
    $tmp = Join-Path $hostDir ("_pull_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    Invoke-Vmrun @("-T", "ws", "-gu", $GuestUser, "-gp", $GuestPassword,
        "copyFileFromGuestToHost", $VmxPath, $guestCsv, $tmp)
    Copy-Item $tmp $hostCsv -Force

    # Optional: power off before next revert (cleaner)
    try { Invoke-Vmrun @("-T", "ws", "stop", $VmxPath, "hard") } catch {}
}

Write-Host ("Fim. Host CSV: {0} | complete={1}" -f $hostCsv, (Get-CompleteCount $hostCsv)) -ForegroundColor Green
