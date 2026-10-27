#Requires -Version 5.1
<#
.SYNOPSIS
  Orquestrador no HOST (maquina fisica). A VM e descartavel.

  Para cada bloco (amostra+repeticao):
    1. reverte snapshot limpo
    2. arranca a VM e espera VMware Tools / Guest Additions
    3. executa so aquele bloco dentro do convidado
    4. copia os JSON para o HOST
    5. passa ao bloco seguinte

  Os resultados vivem no HOST. Reverter a VM ja nao apaga a campanha.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File experiment\scripts\host\Run-HostCampaign.ps1 `
    -CampaignId corpus_aligned_10k `
    -VmxPath "D:\VMs\Win10-TOMWare\Win10-TOMWare.vmx" `
    -SnapshotName tomware_ready `
    -GuestUser marge `
    -GuestPassword "SUA_SENHA"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CampaignId,
    [string]$HostRepoRoot = "",
    [string]$GuestRepoRoot = "C:\TOMWare",
    [ValidateSet("vmware", "virtualbox")]
    [string]$Hypervisor = "vmware",
    [string]$VmxPath = "",
    [string]$VmrunPath = "",
    [string]$VmName = "",
    [string]$SnapshotName = "tomware_ready",
    [Parameter(Mandatory = $true)]
    [string]$GuestUser,
    [Parameter(Mandatory = $true)]
    [string]$GuestPassword,
    [ValidateSet("every_block", "malicious_block")]
    [string]$RevertScope = "every_block",
    [int]$BlockTimeoutMinutes = 30,
    [int]$MaxRetries = 1
)

$ErrorActionPreference = "Stop"

if (-not $HostRepoRoot) {
    $HostRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}

$campaignDir = Join-Path $HostRepoRoot ("experiment\campaigns\" + $CampaignId)
$planPath = Join-Path $campaignDir "execution_plan.csv"
$hostRuns = Join-Path $campaignDir "raw\runs"
$logDir = Join-Path $campaignDir "logs"
New-Item -ItemType Directory -Force -Path $hostRuns | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$hostLog = Join-Path $logDir "host_orchestrator.log"

function Write-HostLog {
    param([string]$Message, [string]$Color = "White")
    $line = "[{0}] {1}" -f (Get-Date).ToString("s"), $Message
    Add-Content -Path $hostLog -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor $Color
}

function Find-Vmrun {
    $cands = New-Object System.Collections.Generic.List[string]
    if ($VmrunPath) { $cands.Add($VmrunPath) }
    $regKeys = @(
        "HKLM:\SOFTWARE\VMware, Inc.\VMware Workstation",
        "HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation",
        "HKLM:\SOFTWARE\VMware, Inc.\VMware Player",
        "HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Player"
    )
    foreach ($rk in $regKeys) {
        if (-not (Test-Path $rk)) { continue }
        try {
            $p = (Get-ItemProperty $rk -ErrorAction Stop).InstallPath
            if ($p) { $cands.Add((Join-Path $p "vmrun.exe")) }
        } catch {}
    }
    @(
        "D:\VMware\VMware Workstation\vmrun.exe",
        "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe",
        "C:\Program Files\VMware\VMware Workstation\vmrun.exe",
        "C:\Program Files (x86)\VMware\VMware Player\vmrun.exe",
        "C:\Program Files\VMware\VMware Player\vmrun.exe"
    ) | ForEach-Object { $cands.Add($_) }
    foreach ($c in $cands) {
        if ($c -and (Test-Path -LiteralPath $c)) { return (Resolve-Path -LiteralPath $c).Path }
    }
    $cmd = Get-Command vmrun.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-VBoxManage {
    $cands = @(
        "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
    )
    foreach ($c in $cands) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$vmrun = $null
$vbox = $null
if ($Hypervisor -eq "vmware") {
    $vmrun = Find-Vmrun
    if (-not $vmrun) { throw "vmrun.exe nao encontrado. Instale VMware Workstation/Player ou passe o hypervisor virtualbox." }
    if (-not $VmxPath) { throw "Informe -VmxPath com o caminho do .vmx" }
    if (-not (Test-Path $VmxPath)) { throw "VMX nao encontrado: $VmxPath" }
    Write-HostLog ("vmrun: " + $vmrun) "Cyan"
} else {
    $vbox = Find-VBoxManage
    if (-not $vbox) { throw "VBoxManage.exe nao encontrado." }
    if (-not $VmName) { throw "Informe -VmName (nome da VM no VirtualBox)" }
    Write-HostLog ("VBoxManage: " + $vbox) "Cyan"
}

function Invoke-Vmrun {
    param([string[]]$VmrunArgs)
    & $vmrun -T ws @VmrunArgs
}

function Restore-CleanSnapshot {
    Write-HostLog ("Revert snapshot: " + $SnapshotName) "Magenta"
    if ($Hypervisor -eq "vmware") {
        Write-HostLog "VM stop hard..." "DarkGray"
        Invoke-Vmrun @("stop", $VmxPath, "hard") 2>$null | Out-Null
        Start-Sleep -Seconds 3
        Write-HostLog "revertToSnapshot $SnapshotName (RAM, pode demorar 1-3 min)..." "DarkGray"
        Invoke-Vmrun @("revertToSnapshot", $VmxPath, $SnapshotName) | Out-Null
        Write-HostLog "revert concluido" "DarkGray"
        Start-Sleep -Seconds 2
        $alreadyOn = $false
        try {
            $listed = (Invoke-Vmrun @("list") | Out-String)
            if ($listed -and ($listed -like "*$VmxPath*")) { $alreadyOn = $true }
        } catch {}
        if (-not $alreadyOn) {
            Invoke-Vmrun @("start", $VmxPath, "gui") | Out-Null
        }
        $ok = $false
        for ($i = 0; $i -lt 60; $i++) {
            Start-Sleep -Seconds 5
            $st = ""
            try { $st = (Invoke-Vmrun @("checkToolsState", $VmxPath) | Out-String).Trim() } catch {}
            if ($st -match "running") { $ok = $true; break }
            Write-HostLog ("Aguardando Tools... (" + $st + ")") "DarkGray"
            if ($st -match "installed" -and $i -eq 12) {
                Write-HostLog "Tools='installed' ha ~1 min: Windows provavelmente esta no ecran de Recuperacao (snapshot sem RAM / power-off sujo). Ctrl+C, arranque normal, snapshot COM memoria com a VM ligada." "Yellow"
            }
        }
        if (-not $ok) { throw "VMware Tools nao ficou ready apos revert." }
        Start-Sleep -Seconds 8
        Copy-RunnerToGuest
    } else {
        & $vbox controlvm $VmName poweroff 2>$null | Out-Null
        Start-Sleep -Seconds 3
        & $vbox snapshot $VmName restore $SnapshotName | Out-Null
        & $vbox startvm $VmName --type gui | Out-Null
        Start-Sleep -Seconds 40
    }
}

$script:GuestRunnerUpdated = $false
function Copy-RunnerToGuest {
    $script:GuestRunnerUpdated = $false
    if ($Hypervisor -ne "vmware") { return }
    $src = Join-Path $HostRepoRoot "experiment\scripts\runner\Run-Campaign.ps1"
    $dst = "$GuestRepoRoot\experiment\scripts\runner\Run-Campaign.ps1"
    if (-not (Test-Path -LiteralPath $src)) { return }
    try {
        Invoke-Vmrun @(
            "-gu", $GuestUser, "-gp", $GuestPassword,
            "CopyFileFromHostToGuest", $VmxPath, $src, $dst
        ) 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $script:GuestRunnerUpdated = $true
            Write-HostLog "Run-Campaign.ps1 copiado para o guest" "DarkGray"
        } else {
            Write-HostLog "CopyFileFromHostToGuest Run-Campaign.ps1 falhou; guest usa o script do snapshot" "Yellow"
        }
    } catch {
        Write-HostLog ("Falha ao copiar Run-Campaign.ps1: " + $_) "Yellow"
    }
}

function Get-HostHeartbeatText {
    $hbGuest = "$GuestRepoRoot\experiment\campaigns\$CampaignId\logs\heartbeat.txt"
    $hbHost = Join-Path $logDir "guest_heartbeat.txt"
    if (Test-Path $hbHost) { Remove-Item $hbHost -Force -ErrorAction SilentlyContinue }
    try {
        Invoke-Vmrun @(
            "-gu", $GuestUser, "-gp", $GuestPassword,
            "CopyFileFromGuestToHost", $VmxPath, $hbGuest, $hbHost
        ) 2>$null | Out-Null
    } catch {}
    if (Test-Path $hbHost) { return ((Get-Content $hbHost -Raw -ErrorAction SilentlyContinue).Trim()) }
    return ""
}

function Test-GuestLaunchFinished {
    param([string]$Heartbeat, [string]$BlockId)
    if (-not $Heartbeat) { return $false }
    if ($Heartbeat -notmatch ("block=" + [regex]::Escape($BlockId))) { return $false }
    if ($Heartbeat -notmatch 'idx=(\d+)/(\d+)') { return $false }
    $i = [int]$Matches[1]
    $n = [int]$Matches[2]
    return ($i -ge $n)
}

function Write-HostCloseoutJson {
    param($PlanRow, [string]$Reason)
    $dest = Join-Path $hostRuns ($PlanRow.run_id + ".json")
    if (Test-Path $dest) { return }
    $now = (Get-Date).ToUniversalTime().ToString("o")
    $mods = @()
    if ($PlanRow.modules_enabled) {
        $mods = @($PlanRow.modules_enabled -split ";" | Where-Object { $_ })
    }
    $rec = [ordered]@{
        schema_version = 1
        identification = [ordered]@{
            campaign_id            = [string]$PlanRow.campaign_id
            run_id                 = [string]$PlanRow.run_id
            sample_id              = [string]$PlanRow.sample_id
            sha256                 = [string]$PlanRow.sha256
            block_id               = [string]$PlanRow.block_id
            repetition             = [int]$PlanRow.repetition
            condition              = [string]$PlanRow.condition
            modules_enabled        = @($mods)
            run_order              = [int]$PlanRow.order_in_block
            random_seed            = [int]$PlanRow.random_seed
            host_id                = $env:COMPUTERNAME
            vm_id                  = "Windows 10 x64-tomware"
            snapshot_id            = $SnapshotName
            restore_completed      = $true
            start_timestamp_utc    = $now
            end_timestamp_utc      = $now
            monotonic_duration_ms  = 0
            configuration_hash     = ""
        }
        operational_outcome = [ordered]@{
            launch_success              = $false
            pid                         = 0
            parent_pid                  = 0
            natural_completion          = $false
            timeout                     = $true
            still_active_at_window_end  = $false
            controlled_termination      = $false
            crash                       = $false
            exception_code              = $null
            exit_code                   = $null
            termination_reason          = "launch_failed"
            observation_duration_ms     = 0
            time_to_first_activity_ms   = $null
            collector_failure           = $false
            missing_reason              = $Reason
        }
        timing_and_cpu = [ordered]@{
            wall_clock_ms      = 0
            cpu_user_ms        = 0
            cpu_kernel_ms      = 0
            cpu_total_ms       = 0
            cpu_percent_mean   = 0
            cpu_percent_max    = 0
            logical_processors = [Environment]::ProcessorCount
        }
        memory = [ordered]@{
            peak_working_set_bytes    = 0
            average_working_set_bytes = 0
            peak_private_bytes        = 0
            average_private_bytes     = 0
            sample_count              = 0
        }
        io = [ordered]@{
            bytes_read       = 0
            bytes_written    = 0
            read_operations  = 0
            write_operations = 0
            files_created    = @()
            files_modified   = @()
            files_deleted    = @()
        }
        processes_threads_modules = [ordered]@{
            peak_tracked_processes = 0
            peak_tracked_threads   = 0
            child_pids             = @()
            loaded_modules_count   = 0
        }
        behavioral_fidelity = [ordered]@{
            stdout_sha256 = ""
            stderr_sha256 = ""
            stdout_bytes  = 0
            stderr_bytes  = 0
        }
        artifacts = [ordered]@{
            raw_record_json_path      = $dest
            stdout_path               = $null
            stderr_path               = $null
            resource_time_series_path = $null
        }
    }
    ($rec | ConvertTo-Json -Depth 6) | Set-Content -Path $dest -Encoding UTF8
    $csv = Join-Path $logDir "host_closeouts.csv"
    $line = "{0},{1},{2},{3}" -f (Get-Date).ToUniversalTime().ToString("o"), $PlanRow.block_id, $PlanRow.run_id, $Reason
    Add-Content -Path $csv -Value $line -Encoding UTF8
    Write-HostLog ("closeout {0} ({1}) reason={2}" -f $PlanRow.run_id, $PlanRow.condition, $Reason) "Yellow"
}

function Close-MissingRuns {
    param($PlanRows, [string]$Reason)
    $n = 0
    foreach ($r in $PlanRows) {
        $p = Join-Path $hostRuns ($r.run_id + ".json")
        if (-not (Test-Path $p)) {
            Write-HostCloseoutJson -PlanRow $r -Reason $Reason
            $n++
        }
    }
    return $n
}

function Start-GuestBlock {
    param([string]$BlockId, [string]$SkipRunIds = "")
    $ps = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $guestScript = "$GuestRepoRoot\experiment\scripts\runner\Run-Campaign.ps1"
    Write-HostLog ("Launch guest: $guestScript -CampaignId $CampaignId -BlockId $BlockId") "Cyan"
    if ($SkipRunIds) {
        Write-HostLog ("SkipRunIds (ja no host): " + $SkipRunIds) "DarkGray"
    }
    if ($Hypervisor -eq "vmware") {
        $launchArgs = @(
            "-gu", $GuestUser, "-gp", $GuestPassword,
            "runProgramInGuest", $VmxPath, "-noWait",
            $ps,
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $guestScript,
            "-CampaignId", $CampaignId,
            "-BlockId", $BlockId
        )
        if ($SkipRunIds -and $script:GuestRunnerUpdated) {
            $launchArgs += @("-SkipRunIds", $SkipRunIds)
        } elseif ($SkipRunIds -and -not $script:GuestRunnerUpdated) {
            Write-HostLog "SkipRunIds ignorado (guest sem script novo)" "Yellow"
        }
        $launchOut = Invoke-Vmrun $launchArgs 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-HostLog ("runProgramInGuest falhou exit=$LASTEXITCODE : " + $launchOut.Trim()) "Red"
            throw "Falha ao lancar bloco no guest (vmrun)."
        }
        Start-Sleep -Seconds 8
        $hb = Get-HostHeartbeatText
        if ($hb -and ($hb -match ("block=" + [regex]::Escape($BlockId)))) {
            Write-HostLog ("heartbeat: " + $hb) "Green"
        } else {
            Write-HostLog "heartbeat ainda nao apareceu ou e de outro bloco" "Yellow"
        }
    } else {
        & $vbox guestcontrol $VmName run --username $GuestUser --password $GuestPassword --exe $ps -- -NoProfile -ExecutionPolicy Bypass -File $guestScript -CampaignId $CampaignId -BlockId $BlockId | Out-Null
    }
}

function Get-GuestRunList {
    $guestRuns = "$GuestRepoRoot\experiment\campaigns\$CampaignId\raw\runs"
    $names = @()
    if ($Hypervisor -eq "vmware") {
        $raw = Invoke-Vmrun @(
            "-gu", $GuestUser, "-gp", $GuestPassword,
            "listDirectoryInGuest", $VmxPath, $guestRuns
        ) 2>$null
        foreach ($line in @($raw)) {
            if ($line -match "\.json$") { $names += $line.Trim() }
        }
    }
    return $names
}

function Copy-GuestJsonToHost {
    param([string[]]$Names)
    $guestRuns = "$GuestRepoRoot\experiment\campaigns\$CampaignId\raw\runs"
    $copied = 0
    foreach ($n in $Names) {
        $dest = Join-Path $hostRuns $n
        if (Test-Path $dest) { continue }
        $src = "$guestRuns\$n"
        try {
            if ($Hypervisor -eq "vmware") {
                Invoke-Vmrun @(
                    "-gu", $GuestUser, "-gp", $GuestPassword,
                    "CopyFileFromGuestToHost", $VmxPath, $src, $dest
                ) | Out-Null
            } else {
                & $vbox guestcontrol $VmName copyfrom --username $GuestUser --password $GuestPassword $src $dest | Out-Null
            }
            if (Test-Path $dest) { $copied++ }
        } catch {
            Write-HostLog ("Falha ao copiar $n : " + $_) "Yellow"
        }
    }
    return $copied
}

if (-not (Test-Path $planPath)) { throw "execution_plan.csv ausente no HOST: $planPath" }
$plan = Import-Csv -Path $planPath -Encoding UTF8
$blocks = [System.Collections.Generic.List[object]]::new()
$seen = @{}
foreach ($r in $plan) {
    if (-not $seen.ContainsKey($r.block_id)) {
        $seen[$r.block_id] = $true
        $blocks.Add([PSCustomObject]@{
            block_id = $r.block_id
            sample_id = $r.sample_id
            group = $r.group
            repetition = $r.repetition
            expected = @($plan | Where-Object { $_.block_id -eq $r.block_id }).Count
        })
    }
}

Write-HostLog ("Campanha HOST: $CampaignId | blocos: " + $blocks.Count + " | revert: $RevertScope") "Cyan"

$blockIdx = 0
foreach ($b in $blocks) {
    $blockIdx++
    $expectedNames = @($plan | Where-Object { $_.block_id -eq $b.block_id } | ForEach-Object { $_.run_id + ".json" })
    $have = @($expectedNames | Where-Object { Test-Path (Join-Path $hostRuns $_) }).Count
    if ($have -ge $b.expected) {
        Write-HostLog ("[{0}/{1}] SKIP bloco {2} (ja no host)" -f $blockIdx, $blocks.Count, $b.block_id) "DarkGray"
        continue
    }

    $blockRows = @($plan | Where-Object { $_.block_id -eq $b.block_id })
    $already = @($blockRows | Where-Object { Test-Path (Join-Path $hostRuns ($_.run_id + ".json")) } | ForEach-Object { $_.run_id })
    $skipCsv = ($already -join ",")

    $needRevert = $true
    if ($RevertScope -eq "malicious_block" -and $b.group -eq "benign") {
        $needRevert = $false
    }

    $attempt = 0
    $okBlock = $false
    while ($attempt -le $MaxRetries -and -not $okBlock) {
        $attempt++
        $already = @($blockRows | Where-Object { Test-Path (Join-Path $hostRuns ($_.run_id + ".json")) } | ForEach-Object { $_.run_id })
        $skipCsv = ($already -join ",")
        Write-HostLog ("[{0}/{1}] bloco {2} ({3}) tentativa {4} (ja no host: {5}/{6})" -f $blockIdx, $blocks.Count, $b.block_id, $b.group, $attempt, $already.Count, $b.expected) "White"
        if ($needRevert -or $attempt -gt 1) {
            Restore-CleanSnapshot
        } else {
            Copy-RunnerToGuest
        }
        Start-GuestBlock -BlockId $b.block_id -SkipRunIds $skipCsv

        $deadline = (Get-Date).AddMinutes($BlockTimeoutMinutes)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 15
            $null = Copy-GuestJsonToHost -Names $expectedNames
            $haveNow = @($expectedNames | Where-Object { Test-Path (Join-Path $hostRuns $_) }).Count
            $hb = Get-HostHeartbeatText
            $guestDone = Test-GuestLaunchFinished -Heartbeat $hb -BlockId $b.block_id
            Write-HostLog ("  progresso bloco: $haveNow / $($b.expected)" + $(if ($guestDone) { " (guest terminou)" } else { "" })) "DarkGray"
            if ($haveNow -ge $b.expected) { $okBlock = $true; break }
            if ($guestDone) {
                $closed = Close-MissingRuns -PlanRows $blockRows -Reason "guest_finished_without_json"
                Write-HostLog ("Guest acabou o bloco; closeout de {0} run(s) sem JSON." -f $closed) "Yellow"
                $haveNow = @($expectedNames | Where-Object { Test-Path (Join-Path $hostRuns $_) }).Count
                $okBlock = ($haveNow -ge $b.expected)
                break
            }
        }
        if (-not $okBlock) {
            Write-HostLog ("Timeout no bloco " + $b.block_id) "Red"
        }
    }
    if (-not $okBlock) {
        $closed = Close-MissingRuns -PlanRows $blockRows -Reason "host_block_timeout_after_retries"
        Write-HostLog ("Bloco " + $b.block_id + " incompleto; closeout de $closed run(s). Nao reprocessar no resume.") "Red"
    }
}

Write-HostLog "Campanha HOST concluida. Resultados em $hostRuns" "Green"
