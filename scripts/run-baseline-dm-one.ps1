#Requires -Version 5.1
<#
.SYNOPSIS
    Runs pin_baseline and pin + one countermeasure on the same sample; prints both on one screen.

.EXAMPLE
    cd C:\TOMWare
    .\scripts\run-baseline-dm-one.ps1 -Sha256 36685efcf34c7a7a6f6dd2e48199e4700b5ab8fe3945a50297703dd8daced74f -Countermeasure dm

.EXAMPLE
    .\scripts\run-baseline-dm-one.ps1 -Sha256 36685efcf34c7a7a6f6dd2e48199e4700b5ab8fe3945a50297703dd8daced74f -Countermeasure do

.EXAMPLE
    .\scripts\run-baseline-dm-one.ps1 -Sha256 36685efcf34c7a7a6f6dd2e48199e4700b5ab8fe3945a50297703dd8daced74f -Countermeasure do -ShowOnly

.EXAMPLE
    .\scripts\run-baseline-dm-one.ps1 -Sha256 36685efc... -Countermeasure dm -Loop1000
#>
[CmdletBinding()]
param(
    [string]$Sha256 = "0e3e95ee6649238171fb409c143c8a944bc54332f0ce85b94c651b5d0bf95343",
    [ValidateSet("de", "dm", "do", "dd", "dp", "da")]
    [string]$Countermeasure = "dm",
    [string]$SamplesDir = "C:\TOMWare\malwares\infected",
    [string]$SignatureFile = "config/signatures.txt",
    [int]$TimeoutSeconds = 120,
    [int]$MemscanTimeoutSeconds = 120,
    [bool]$FollowChild = $true,
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [switch]$ShowOnly,
    [switch]$SkipMemscan,
    [switch]$Loop1000
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot
. (Join-Path $repoRoot "scripts/lib/TomwareBenchmark.ps1")

$PocByKnob = @{
    de = @{
        Module = "SanitizePinEnvVars"
        PocName = "TestGetEnvironments.exe"
        RelPaths = @("Resultados/Apps-Teste/TestGetEnvironments.exe")
        UsesMemscan = $false
        BaselineKnobs = @("-q")
        PocTimeout = 120
        DetectPattern = "Alerta:"
        StealthPattern = "OK - nenhuma anomalia"
    }
    dm = @{
        Module = "InstMemcmpMask"
        PocName = "TestMemoryScan.exe"
        RelPaths = @(
            "Resultados/Apps-Teste/TestMemoryScan.exe",
            "Resultados/Apps-Teste/TestMemoryScan/TestMemoryScan.exe"
        )
        UsesMemscan = $true
        BaselineKnobs = @("-q")
        PocTimeout = 120
        DetectPattern = "Alerta:"
        StealthMustNotMatch = $true
    }
    do = @{
        Module = "SkewMask"
        PocName = "TestOverhead.exe"
        RelPaths = @("Resultados/Apps-Teste/TestOverhead.exe")
        UsesMemscan = $false
        BaselineKnobs = @("-go", "-q")
        PocCmExtra = @("-go")
        PocTimeout = 180
        DetectPattern = "Overhead anomalo|possivel DBI|\*\*\* Overhead"
        StealthPattern = "OK - nenhuma anomalia"
    }
    dd = @{
        Module = "AntiDebug"
        PocName = "TestAntiDebug.exe"
        RelPaths = @("Resultados/Apps-Teste/TestAntiDebug.exe")
        UsesMemscan = $false
        BaselineKnobs = @("-gdb", "-q")
        PocTimeout = 120
        DetectPattern = "Alerta:"
        StealthPattern = "OK - nenhuma anomalia"
    }
    dp = @{
        Module = "ProcessEnum"
        PocName = "TestProcessEnum.exe"
        RelPaths = @("Resultados/Apps-Teste/TestProcessEnum.exe")
        UsesMemscan = $false
        # Vestigio funcional (app de teste). Amostra real sob Pin costuma timeout — nao entra na comparacao quantitativa.
        FunctionalOnly = $true
        BaselineKnobs = @("-q")
        PocTimeout = 120
        DetectPattern = "Alerta:"
        StealthPattern = "OK - nenhuma anomalia"
    }
    da = @{
        Module = "All countermeasures"
        PocName = "TestMemoryScan.exe"
        RelPaths = @(
            "Resultados/Apps-Teste/TestMemoryScan.exe",
            "Resultados/Apps-Teste/TestMemoryScan/TestMemoryScan.exe"
        )
        UsesMemscan = $true
        BaselineKnobs = @("-q")
        PocTimeout = 300
        DetectPattern = "Alerta:"
        StealthMustNotMatch = $true
    }
}

$CmProvesRef = @{
    de = @{ Proves = "Pin environment variables hidden" }
    dm = @{ Proves = "memory fingerprints masked (PIN_=0)" }
    do = @{ Proves = "timing overhead masked (no anomaly)" }
    dd = @{ Proves = "PEB anti-debug indicators masked" }
    dp = @{ Proves = "pin.exe hidden in process enumeration" }
    da = @{ Proves = "all countermeasures active (-de -dm -do -dd -dp)" }
}

function Get-PocConfig {
    param([string]$Knob)
    return $PocByKnob[$Knob]
}

function Test-CmUsesMemscan {
    param([string]$Knob)
    return $PocByKnob[$Knob].UsesMemscan
}

function Test-CmFunctionalOnly {
    param([string]$Knob)
    return [bool]$PocByKnob[$Knob].FunctionalOnly
}

function Test-MalwareTimeQuantitative {
    param([object]$MalwareRun)
    if (-not $MalwareRun) { return $false }
    return ($MalwareRun.Outcome -eq "complete")
}

function Format-MalwareResultLine {
    param(
        [string]$Knob,
        [object]$MalwareRun
    )

    $exitDisp = if ($null -eq $MalwareRun.ExitCode -or $MalwareRun.ExitCode -eq "") { "-" } else { $MalwareRun.ExitCode }
    $functionalOnly = Test-CmFunctionalOnly -Knob $Knob
    $timeOk = Test-MalwareTimeQuantitative -MalwareRun $MalwareRun

    if ($functionalOnly) {
        # Processo/enumeracao: evidencia na caixa do app de teste; tempo da amostra nao e metrica do -dp.
        if ($MalwareRun.Outcome -eq "skipped") {
            return "    Result  : evidência = caixa acima (pin.exe) | amostra real nao executada"
        }
        if ($timeOk) {
            return ("    Result  : evidência = caixa acima (pin.exe) | amostra outcome={0} time={1}s (nao metrica de -{2}) | exit={3}" -f `
                $MalwareRun.Outcome, $MalwareRun.Seconds, $Knob, $exitDisp)
        }
        return ("    Result  : evidência = caixa acima (pin.exe) | amostra outcome={0} (nao metrica de -{1}) | exit={2}" -f `
            $MalwareRun.Outcome, $Knob, $exitDisp)
    }

    if (-not $timeOk) {
        return ("    Result  : outcome={0} (tempo nao quantitativo; reexecutar ate complete) | wall={1}s | exit={2}" -f `
            $MalwareRun.Outcome, $MalwareRun.Seconds, $exitDisp)
    }

    return ("    Result  : outcome={0} | time={1}s | exit={2}" -f $MalwareRun.Outcome, $MalwareRun.Seconds, $exitDisp)
}

function Resolve-PocPath {
    param(
        [string]$Knob,
        [switch]$Loop1000
    )
    $cfg = Get-PocConfig -Knob $Knob
    $candidates = @()
    if ($Loop1000) {
        foreach ($rel in $cfg.RelPaths) {
            $leaf = Split-Path $rel -Leaf
            $candidates += (Join-Path $repoRoot "Resultados/Apps-Teste/Loop_X_1000/$leaf")
        }
    }
    foreach ($rel in $cfg.RelPaths) {
        $candidates += (Join-Path $repoRoot $rel)
    }
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-PocBaselineKnobs {
    param([string]$Knob)
    return @($PocByKnob[$Knob].BaselineKnobs)
}

function Get-PocCmKnobs {
    param(
        [string]$Knob,
        [string]$SignatureFile
    )
    $knobs = @(Get-CountermeasureKnobs -Knob $Knob -SignatureFile $SignatureFile)
    if ($PocByKnob[$Knob].PocCmExtra) {
        foreach ($k in $PocByKnob[$Knob].PocCmExtra) {
            if ($knobs -notcontains $k) { $knobs += $k }
        }
    }
    return $knobs
}

function Get-PocTimeout {
    param(
        [string]$Knob,
        [switch]$Loop1000
    )
    $cfg = Get-PocConfig -Knob $Knob
    $base = if ($cfg.PocTimeout) { [int]$cfg.PocTimeout } else { $MemscanTimeoutSeconds }
    if ($Loop1000) {
        # Loop amplifica o tempo. Memscan x1000 sob Pin e muito pesado.
        # O app imprime o Resumo apos a 1a varredura, mas continua executando
        # as outras 999 varreduras reais para preservar a medicao.
        switch ($Knob) {
            "do" { return [Math]::Max($base, 900) }
            "dm" { return [Math]::Max($base, 14400) }
            "da" { return [Math]::Max($base, 14400) }
            default { return [Math]::Max($base, 300) }
        }
    }
    return $base
}

function Get-CountermeasureKnobs {
    param(
        [string]$Knob,
        [string]$SignatureFile
    )
    $knobs = @("-$Knob", "-q")
    if ($Knob -in @("dm", "da")) {
        $knobs += "-sf", $SignatureFile
    }
    return $knobs
}

function Build-PinCommandLine {
    param(
        [string]$PinExe,
        [string]$ToolDll,
        [string]$SamplePath,
        [string[]]$Knobs = @(),
        [switch]$FollowChild
    )

    $pinPath = (Resolve-Path $PinExe).Path
    $dllPath = (Resolve-Path $ToolDll).Path
    $sampleResolved = (Resolve-Path $SamplePath).Path
    $sampleArg = if ($sampleResolved -match '\s') { "`"$sampleResolved`"" } else { $sampleResolved }

    $parts = @($pinPath)
    if ($FollowChild) { $parts += "-follow_execv", "1" }
    $parts += "-t", $dllPath
    if ($Knobs) { $parts += $Knobs }
    $parts += "--", $sampleArg
    return ($parts -join " ")
}

function Get-PinCommandFromRun {
    param(
        [object]$Run,
        [string]$PinExe,
        [string]$ToolDll,
        [string]$SamplePath,
        [string[]]$Knobs,
        [switch]$FollowChild
    )

    if ($PinExe -and $ToolDll -and $SamplePath -and (Test-Path $PinExe) -and (Test-Path $ToolDll) -and (Test-Path $SamplePath)) {
        return Build-PinCommandLine -PinExe $PinExe -ToolDll $ToolDll -SamplePath $SamplePath -Knobs $Knobs -FollowChild:$FollowChild
    }
    if ($Run -and $Run.Command) { return [string]$Run.Command }
    return $null
}

function Show-PinCommandLine {
    param(
        [string]$Command,
        [string]$HighlightKnob
    )

    if (-not $Command) { return }

    $indent = "    "
    if ($HighlightKnob) {
        $token = "-$HighlightKnob"
        $idx = $Command.IndexOf($token)
        if ($idx -ge 0) {
            Write-Host $indent -NoNewline
            if ($idx -gt 0) { Write-Host $Command.Substring(0, $idx) -NoNewline }
            Write-Host $token -ForegroundColor Red -NoNewline
            $rest = $Command.Substring($idx + $token.Length)
            if ($rest) { Write-Host $rest }
            else { Write-Host "" }
            return
        }
    }

    Write-Host ("{0}{1}" -f $indent, $Command)
}
function Write-RedBoxLines {
    param(
        [string[]]$Lines,
        [string]$Indent = "    "
    )

    if (-not $Lines -or $Lines.Count -eq 0) { return }

    $innerWidth = ($Lines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $bar = ("-" * ($innerWidth + 2))

    Write-Host ("{0}+{1}+" -f $Indent, $bar) -ForegroundColor Red
    foreach ($line in $Lines) {
        Write-Host ("{0}| {1} |" -f $Indent, $line.PadRight($innerWidth)) -ForegroundColor Red
    }
    Write-Host ("{0}+{1}+" -f $Indent, $bar) -ForegroundColor Red
}

function Format-PocDisplayLine {
    param([string]$Line)
    # Mantem o padrao de saida do artigo (portugues), sem traduzir.
    return $Line.Trim()
}

function Get-PocHighlightLines {
    param([string]$Stdout)
    if (-not $Stdout) { return @("(sem stdout)") }
    $hits = @()
    foreach ($line in ($Stdout -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t) { continue }
        if ($t -match 'Resumo de ocorr|Ocorr|Alerta:|PIN_\s*:|pin\.exe\s*:|pinvm\.dll|pinipc\.dll|Ticks \+ Latencia|Sleep invocado|Overhead anomalo|OK - nenhuma anomalia|IsDebuggerPresent|CheckRemoteDebuggerPresent|ProcessDebugPort|ProcessDebugObjectHandle|PEB\.BeingDebugged|PEB\.NtGlobalFlag|BeingDebugged|TOMWare\.dll|PIN_APP_LD|PIN_CRT_TZDATA|Limite:') {
            $hits += $t
        }
    }
    if ($hits.Count -eq 0) {
        return @("(ver stdout completo)")
    }
    return $hits | Select-Object -Last 12
}

function Show-PocEvidence {
    param(
        [string]$Knob,
        [object]$PocRun,
        [object]$Counts,
        [string]$PinCommand,
        [string]$HighlightKnob
    )
    $cfg = Get-PocConfig -Knob $Knob

    if ($PinCommand) {
        Show-PinCommandLine -Command $PinCommand -HighlightKnob $HighlightKnob
    }

    Write-Host ("    {0} | run: {1}s | {2}" -f $cfg.PocName, $PocRun.Seconds, $PocRun.Outcome)

    if ($cfg.UsesMemscan) {
        $hasCounts = ($null -ne $Counts.PIN_) -or ($null -ne $Counts.pin_exe) -or
                     ($null -ne $Counts.pinvm_dll) -or ($null -ne $Counts.pinipc_dll)
        if ($hasCounts) {
            $boxLines = @(
                "Resumo de ocorrências:",
                ("PIN_     : {0}" -f $(if ($null -ne $Counts.PIN_) { $Counts.PIN_ } else { "n/a" })),
                ("pin.exe  : {0}" -f $(if ($null -ne $Counts.pin_exe) { $Counts.pin_exe } else { "n/a" })),
                ("pinvm.dll : {0}" -f $(if ($null -ne $Counts.pinvm_dll) { $Counts.pinvm_dll } else { "n/a" })),
                ("pinipc.dll : {0}" -f $(if ($null -ne $Counts.pinipc_dll) { $Counts.pinipc_dll } else { "n/a" }))
            )
            Write-RedBoxLines -Lines $boxLines
        }
        else {
            # Timeout / stdout parcial: exibe o que veio do app de teste (Resumo impresso cedo).
            $displayLines = @(Get-PocHighlightLines -Stdout $PocRun.Stdout)
            Write-RedBoxLines -Lines $displayLines
        }
    }
    else {
        $displayLines = @()
        foreach ($line in (Get-PocHighlightLines -Stdout $PocRun.Stdout)) {
            $displayLines += (Format-PocDisplayLine -Line $line)
        }
        Write-RedBoxLines -Lines $displayLines
    }
}

function Test-PocDetect {
    param(
        [string]$Knob,
        [object]$PocRun,
        [object]$Counts,
        [bool]$IsBaseline
    )
    $cfg = Get-PocConfig -Knob $Knob
    if ($cfg.UsesMemscan) {
        if ($IsBaseline) {
            return ($null -ne $Counts.PIN_ -and $Counts.PIN_ -gt 4) -or ($PocRun.Stdout -match $cfg.DetectPattern)
        }
        if ($cfg.StealthMustNotMatch) {
            return ($PocRun.Stdout -notmatch "Alerta:") -and ($null -eq $Counts.PIN_ -or $Counts.PIN_ -le 4)
        }
        return $false
    }
    if ($IsBaseline) {
        return $PocRun.Stdout -match $cfg.DetectPattern
    }
    return $PocRun.Stdout -match $cfg.StealthPattern
}

function Get-TestMemoryScanPath {
    @(
        (Join-Path $repoRoot "Resultados/Apps-Teste/TestMemoryScan.exe"),
        (Join-Path $repoRoot "Resultados/Apps-Teste/TestMemoryScan/TestMemoryScan.exe")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Parse-MemscanCounts {
    param([string]$Stdout)
    $r = @{ PIN_ = $null; pin_exe = $null; pinvm_dll = $null; pinipc_dll = $null }
    if (-not $Stdout) { return $r }
    foreach ($line in ($Stdout -split "`r?`n")) {
        if ($line -match '^\s*PIN_\s*:\s*(\d+)')       { $r.PIN_ = [int]$Matches[1] }
        if ($line -match '^\s*pin\.exe\s*:\s*(\d+)')   { $r.pin_exe = [int]$Matches[1] }
        if ($line -match '^\s*pinvm\.dll\s*:\s*(\d+)') { $r.pinvm_dll = [int]$Matches[1] }
        if ($line -match '^\s*pinipc\.dll\s*:\s*(\d+)') { $r.pinipc_dll = [int]$Matches[1] }
    }
    return $r
}

function Show-InvocationHeader {
    param(
        [string]$Sha256,
        [string]$Knob,
        [bool]$ShowOnly
    )

    $showArg = if ($ShowOnly) { " show" } else { "" }
    Write-Host ""
    Write-Host "C:\TOMWare>scripts\run-baseline-dm-one.cmd $Sha256 $Knob$showArg"
    Write-Host ""
}

function Show-BaselineReport {
    param(
        [string]$Knob,
        [object]$PocRun,
        [object]$Counts,
        [object]$MalwareRun,
        [string]$PinCommand,
        [string]$SamplePath
    )

    Write-Host ""
    Write-Host "[baseline] Pin + TOMWare (sem contramedida)" -ForegroundColor Red
    if ($SamplePath) {
        Write-Host ("    {0}" -f $SamplePath)
    }
    Show-PocEvidence -Knob $Knob -PocRun $PocRun -Counts $Counts -PinCommand $PinCommand -HighlightKnob $null
    Write-Host (Format-MalwareResultLine -Knob $Knob -MalwareRun $MalwareRun)
}

function Show-CmReport {
    param(
        [string]$Knob,
        [object]$PocRun,
        [object]$Counts,
        [object]$MalwareRun,
        [string]$PinCommand,
        [string]$SamplePath
    )

    $cfg = Get-PocConfig -Knob $Knob

    Write-Host ""
    Write-Host "[-$Knob] Pin + TOMWare + $($cfg.Module) (-$Knob)" -ForegroundColor Red
    if ($SamplePath) {
        Write-Host ("    {0}" -f $SamplePath)
    }
    Show-PocEvidence -Knob $Knob -PocRun $PocRun -Counts $Counts -PinCommand $PinCommand -HighlightKnob $Knob
    Write-Host (Format-MalwareResultLine -Knob $Knob -MalwareRun $MalwareRun)
}

function Get-ComparisonLogLines {
    param(
        [string]$Knob,
        [object]$BaselineMalware,
        [object]$CmMalware,
        [object]$BaselineCounts,
        [object]$CmCounts
    )

    $functionalOnly = Test-CmFunctionalOnly -Knob $Knob
    $baseOk = Test-MalwareTimeQuantitative -MalwareRun $BaselineMalware
    $cmOk = Test-MalwareTimeQuantitative -MalwareRun $CmMalware
    $quantOk = (-not $functionalOnly) -and $baseOk -and $cmOk

    $deltaLine = if ($quantOk) {
        $delta = [math]::Round($CmMalware.Seconds - $BaselineMalware.Seconds, 3)
        $sign = if ($delta -ge 0) { "+" } else { "" }
        ("  delta (-{0} - base) : {1}{2}s" -f $Knob, $sign, $delta)
    }
    elseif ($functionalOnly) {
        "  delta (-$Knob - base) : n/a (eficacia medida pela caixa pin.exe, nao pelo tempo)"
    }
    else {
        "  delta (-$Knob - base) : n/a (timeout/early_exit — tempo nao quantitativo)"
    }

    $baseLine = if ($BaselineMalware.Outcome -eq "skipped") {
        "  malware baseline : skipped"
    }
    elseif ($baseOk -and -not $functionalOnly) {
        ("  malware baseline : {0}s | outcome={1}" -f $BaselineMalware.Seconds, $BaselineMalware.Outcome)
    }
    elseif ($functionalOnly) {
        ("  malware baseline : outcome={0} (executada; tempo nao e metrica de -{1})" -f $BaselineMalware.Outcome, $Knob)
    }
    else {
        ("  malware baseline : outcome={0} (tempo nao quantitativo; wall={1}s)" -f $BaselineMalware.Outcome, $BaselineMalware.Seconds)
    }

    $cmLine = if ($CmMalware.Outcome -eq "skipped") {
        "  malware -$Knob      : skipped"
    }
    elseif ($cmOk -and -not $functionalOnly) {
        ("  malware -{0}      : {1}s | outcome={2}" -f $Knob, $CmMalware.Seconds, $CmMalware.Outcome)
    }
    elseif ($functionalOnly) {
        ("  malware -{0}      : outcome={1} (executada; tempo nao e metrica de -{0})" -f $Knob, $CmMalware.Outcome)
    }
    else {
        ("  malware -{0}      : outcome={1} (tempo nao quantitativo; wall={2}s)" -f $Knob, $CmMalware.Outcome, $CmMalware.Seconds)
    }

    return @(
        "",
        "============================================================",
        " comparison | baseline vs -$Knob (same sample)",
        "============================================================",
        "",
        $baseLine,
        $cmLine,
        $deltaLine,
        "",
        ("  memscan PIN_     : baseline={0} | -{1}={2}" -f `
            $(if ($null -ne $BaselineCounts.PIN_) { $BaselineCounts.PIN_ } else { "n/a" }), `
            $Knob, `
            $(if ($CmCounts -and $null -ne $CmCounts.PIN_) { $CmCounts.PIN_ } else { "n/a" })),
        "",
        "============================================================",
        ""
    )
}

function Get-CountermeasureVerdict {
    param(
        [string]$Knob,
        [object]$BaselineMalware,
        [object]$CmMalware,
        [object]$BaselinePoc,
        [object]$CmPoc,
        [object]$BaselineCounts,
        [object]$CmCounts
    )

    $baseSec = [double]$BaselineMalware.Seconds
    $cmSec = [double]$CmMalware.Seconds
    $delta = $cmSec - $baseSec
    $proves = $CmProvesRef[$Knob]
    $cfg = Get-PocConfig -Knob $Knob
    $baseOk = Test-MalwareTimeQuantitative -MalwareRun $BaselineMalware
    $cmOk = Test-MalwareTimeQuantitative -MalwareRun $CmMalware
    $malwareNote = if ($baseOk -and $cmOk -and -not (Test-CmFunctionalOnly -Knob $Knob)) {
        "Malware: $([math]::Round($baseSec,1))s -> $([math]::Round($cmSec,1))s."
    }
    elseif (Test-CmFunctionalOnly -Knob $Knob) {
        "Real sample exercised; runtime is not a -dp effectiveness metric."
    }
    else {
        "Malware timing discarded (outcome not complete)."
    }

    $vestigeBaseOk = Test-PocDetect -Knob $Knob -PocRun $BaselinePoc -Counts $BaselineCounts -IsBaseline $true
    $vestigeCmOk = Test-PocDetect -Knob $Knob -PocRun $CmPoc -Counts $CmCounts -IsBaseline $false

    if (-not $vestigeBaseOk) {
        return @{ Status = "INCONCLUSIVE"; Color = "Yellow"; Reason = "Baseline did not show Pin detected. Re-run baseline section." }
    }
    if (-not $vestigeCmOk) {
        if ($CmPoc.Outcome -eq "timeout") {
            return @{ Status = "INCONCLUSIVE"; Color = "Yellow"; Reason = "-$Knob vestige check timed out; increase timeout." }
        }
        return @{ Status = "FAIL"; Color = "Red"; Reason = "-$Knob did not mask Pin vestige." }
    }

    if (Test-CmFunctionalOnly -Knob $Knob) {
        return @{ Status = "OK"; Color = "Green"; Reason = "$($cfg.Module) effective (pin.exe masked in test app). $malwareNote" }
    }
    if ($Knob -in @("dm", "da")) {
        $pinBase = $BaselineCounts.PIN_
        $pinCm = $CmCounts.PIN_
        return @{ Status = "OK"; Color = "Green"; Reason = "InstMemcmpMask effective: PIN_ $pinBase -> $pinCm. $malwareNote" }
    }
    if ($Knob -eq "do") {
        return @{ Status = "OK"; Color = "Green"; Reason = "SkewMask effective: no timing anomaly. $malwareNote" }
    }
    if ($Knob -in @("de", "dd")) {
        if ($baseOk -and $cmOk) {
            return @{ Status = "OK"; Color = "Green"; Reason = "$($cfg.Module) effective: vestige masked. Malware: $([math]::Round($baseSec,1))s -> $([math]::Round($cmSec,1))s (+$([math]::Round($delta,1))s)." }
        }
        return @{ Status = "OK"; Color = "Green"; Reason = "$($cfg.Module) effective: vestige masked (functional). $malwareNote" }
    }
    return @{ Status = "OK"; Color = "Green"; Reason = $proves.Proves }
}

function Get-BaselineSubtitle {
    return "[baseline] Pin + TOMWare (no countermeasures)"
}

function Get-CmSubtitle {
    param([string]$Knob)
    $cfg = Get-PocConfig -Knob $Knob
    return "[-$Knob] Pin + TOMWare + $($cfg.Module) (-$Knob only)"
}

function Get-VerdictLogLines {
    param(
        [string]$Knob,
        [object]$BaselineMalware,
        [object]$CmMalware,
        [object]$BaselinePoc,
        [object]$CmPoc,
        [object]$BaselineCounts,
        [object]$CmCounts
    )

    $v = Get-CountermeasureVerdict -Knob $Knob -BaselineMalware $BaselineMalware -CmMalware $CmMalware `
        -BaselinePoc $BaselinePoc -CmPoc $CmPoc -BaselineCounts $BaselineCounts -CmCounts $CmCounts
    $proves = $CmProvesRef[$Knob]

    return @(
        " verdict | -$Knob countermeasure",
        "",
        ("  Proves        : {0}" -f $proves.Proves),
        ("  {0} : $(if (Test-PocDetect -Knob $Knob -PocRun $BaselinePoc -Counts $BaselineCounts -IsBaseline $true) { 'Pin DETECTED' } else { 'not detected' })" -f (Get-BaselineSubtitle)),
        ("  {0} : $(if (Test-PocDetect -Knob $Knob -PocRun $CmPoc -Counts $CmCounts -IsBaseline $false) { 'Pin NOT identified' } else { 'still detected' })" -f (Get-CmSubtitle -Knob $Knob)),
        ("  Status        : {0}" -f $v.Status),
        ("  Reason        : {0}" -f $v.Reason),
        "",
        "============================================================",
        ""
    )
}

function Write-RunSummaryLog {
    param(
        [string]$Tag,
        [string]$Knob,
        [object]$BaselineMalware,
        [object]$CmMalware,
        [object]$BaselinePoc,
        [object]$CmPoc,
        [object]$BaselineCounts,
        [object]$CmCounts
    )

    $outDir = Join-Path $repoRoot "Resultados"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $logPath = Join-Path $outDir "baseline-$Knob-$Tag.log"

    $lines = @()
    $lines += Get-ComparisonLogLines -Knob $Knob -BaselineMalware $BaselineMalware -CmMalware $CmMalware `
        -BaselineCounts $BaselineCounts -CmCounts $CmCounts
    $lines += Get-VerdictLogLines -Knob $Knob -BaselineMalware $BaselineMalware -CmMalware $CmMalware `
        -BaselinePoc $BaselinePoc -CmPoc $CmPoc -BaselineCounts $BaselineCounts -CmCounts $CmCounts

    $lines | Set-Content -Path $logPath -Encoding UTF8
}

function Save-RunArtifacts {
    param(
        [string]$Tag,
        [string]$Knob,
        [object]$BaselineMalware,
        [object]$CmMalware,
        [object]$BaselineMemscan,
        [object]$CmMemscan,
        [object]$BaselineCounts,
        [object]$CmCounts
    )

    $outDir = Join-Path $repoRoot "Resultados"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $BaselineMalware | ConvertTo-Json | Set-Content -Path (Join-Path $outDir "baseline-$Tag.json") -Encoding UTF8
    $CmMalware | ConvertTo-Json | Set-Content -Path (Join-Path $outDir "$Knob-$Tag.json") -Encoding UTF8
    @{ Run = $BaselineMemscan; Counts = $BaselineCounts } | ConvertTo-Json -Depth 4 |
        Set-Content -Path (Join-Path $outDir "memscan-baseline.json") -Encoding UTF8
    if (Test-CmUsesMemscan -Knob $Knob) {
        @{ Run = $CmMemscan; Counts = $CmCounts } | ConvertTo-Json -Depth 4 |
            Set-Content -Path (Join-Path $outDir "memscan-$Knob.json") -Encoding UTF8
    }
    @{
        Sha256          = $Sha256
        Countermeasure  = $Knob
        UsesMemscan     = (Test-CmUsesMemscan -Knob $Knob)
        Knobs           = (Get-CountermeasureKnobs -Knob $Knob -SignatureFile $SignatureFile)
        BaselineMalware = $BaselineMalware
        CmMalware       = $CmMalware
        BaselineMemscan = $BaselineMemscan
        CmMemscan       = $CmMemscan
        BaselineCounts  = $BaselineCounts
        CmCounts        = $CmCounts
    } | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $outDir "baseline-$Knob-$Tag.json") -Encoding UTF8
}

function Assert-SavedCountermeasure {
    param(
        [object]$Saved,
        [string]$Knob
    )
    if ($Saved.Countermeasure -and $Saved.Countermeasure -ne $Knob) {
        throw "Saved data is for -$($Saved.Countermeasure), not -$Knob. Run without -ShowOnly first."
    }
}

function Load-SavedRuns {
    param(
        [string]$Tag,
        [string]$Knob
    )

    $combinedPath = Join-Path $repoRoot "Resultados\baseline-$Knob-$Tag.json"
    if (Test-Path $combinedPath) {
        $saved = Get-Content $combinedPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-SavedCountermeasure -Saved $saved -Knob $Knob
        return @{
            UsesMemscan = if ($null -ne $saved.UsesMemscan) { [bool]$saved.UsesMemscan } else { (Test-CmUsesMemscan -Knob $Knob) }
            BaseMalware = $saved.BaselineMalware
            CmMalware   = $saved.CmMalware
            BaseMemscan = $saved.BaselineMemscan
            CmMemscan   = $saved.CmMemscan
            BaseCounts  = [hashtable]$saved.BaselineCounts
            CmCounts    = if ($saved.CmCounts) { [hashtable]$saved.CmCounts } else { $null }
        }
    }

    # Legacy: baseline-dm-*.json from older script versions
    if ($Knob -eq "dm") {
        $legacyPath = Join-Path $repoRoot "Resultados\baseline-dm-$Tag.json"
        if (Test-Path $legacyPath) {
            $saved = Get-Content $legacyPath -Raw -Encoding UTF8 | ConvertFrom-Json
            return @{
                UsesMemscan = $true
                BaseMalware = $saved.BaselineMalware
                CmMalware   = if ($saved.CmMalware) { $saved.CmMalware } else { $saved.DmMalware }
                BaseMemscan = $saved.BaselineMemscan
                CmMemscan   = if ($saved.CmMemscan) { $saved.CmMemscan } else { $saved.DmMemscan }
                BaseCounts  = [hashtable]$saved.BaselineCounts
                CmCounts    = [hashtable](if ($saved.CmCounts) { $saved.CmCounts } else { $saved.DmCounts })
            }
        }
    }

    $basePath = Join-Path $repoRoot "Resultados\baseline-$Tag.json"
    $cmPath = Join-Path $repoRoot "Resultados\$Knob-$Tag.json"
    if (-not (Test-Path $basePath) -or -not (Test-Path $cmPath)) {
        throw "Missing saved runs for -$Knob (expected $cmPath). Run without -ShowOnly first."
    }

    $usesMemscan = Test-CmUsesMemscan -Knob $Knob
    $baseMemJson = Join-Path $repoRoot "Resultados\memscan-baseline.json"
    if (-not (Test-Path $baseMemJson)) {
        throw "Missing memscan-baseline.json. Run without -ShowOnly or -SkipMemscan."
    }
    $baseSaved = Get-Content $baseMemJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $baseMemscan = $baseSaved.Run
    $baseCounts = Parse-MemscanCounts -Stdout $baseMemscan.Stdout

    $cmMemscan = $null
    $cmCounts = $null
    if ($usesMemscan) {
        $cmMemJson = Join-Path $repoRoot "Resultados\memscan-$Knob.json"
        if (-not (Test-Path $cmMemJson)) {
            throw "Missing memscan-$Knob.json. Run without -ShowOnly first."
        }
        $cmSaved = Get-Content $cmMemJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $cmMemscan = $cmSaved.Run
        $cmCounts = Parse-MemscanCounts -Stdout $cmMemscan.Stdout
    }

    return @{
        UsesMemscan = $usesMemscan
        BaseMalware = Get-Content $basePath -Raw -Encoding UTF8 | ConvertFrom-Json
        CmMalware   = Get-Content $cmPath -Raw -Encoding UTF8 | ConvertFrom-Json
        BaseMemscan = $baseMemscan
        CmMemscan   = $cmMemscan
        BaseCounts  = $baseCounts
        CmCounts    = $cmCounts
    }
}

# --- main ---

if ($Countermeasure -eq "da") {
    if ($TimeoutSeconds -le 120) { $TimeoutSeconds = 300 }
    if ($MemscanTimeoutSeconds -le 120) { $MemscanTimeoutSeconds = 300 }
}

$cmKnobs = Get-CountermeasureKnobs -Knob $Countermeasure -SignatureFile $SignatureFile
$sample = Join-Path $SamplesDir "$Sha256.exe"
$pinExe = Join-Path $repoRoot "pin/pin.exe"
$toolDll = Join-Path $repoRoot "x64/$Configuration/TOMWare.dll"
$tag = $Sha256.Substring(0, 8)

if (-not (Test-Path $sample)) { throw "Sample not found: $sample" }

$pocExe = $null
if (-not $SkipMemscan) {
    $pocExe = Resolve-PocPath -Knob $Countermeasure -Loop1000:$Loop1000
    if (-not $pocExe) {
        $hint = if ($Loop1000) { "Resultados/Apps-Teste/Loop_X_1000" } else { "Resultados/Apps-Teste" }
        throw "$($PocByKnob[$Countermeasure].PocName) not found under $hint"
    }
    if ($Loop1000 -and ($pocExe -notmatch 'Loop_X_1000')) {
        Write-Warning "Loop_X_1000 pedido, mas app de teste sem loop encontrado: $pocExe"
    }
}

if ($ShowOnly) {
    if (-not $pocExe) { $pocExe = Resolve-PocPath -Knob $Countermeasure -Loop1000:$Loop1000 }
    $saved = Load-SavedRuns -Tag $tag -Knob $Countermeasure
    $pocBaseKnobs = Get-PocBaselineKnobs -Knob $Countermeasure
    $pocCmKnobs = Get-PocCmKnobs -Knob $Countermeasure -SignatureFile $SignatureFile
    $basePinCmd = Get-PinCommandFromRun -Run $saved.BaseMemscan -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe -Knobs $pocBaseKnobs
    $cmPinCmd = Get-PinCommandFromRun -Run $saved.CmMemscan -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe -Knobs $pocCmKnobs

    Show-InvocationHeader -Sha256 $Sha256 -Knob $Countermeasure -ShowOnly:$true
    Show-BaselineReport -Knob $Countermeasure -PocRun $saved.BaseMemscan -Counts $saved.BaseCounts -MalwareRun $saved.BaseMalware -PinCommand $basePinCmd -SamplePath $sample
    Show-CmReport -Knob $Countermeasure -PocRun $saved.CmMemscan -Counts $saved.CmCounts -MalwareRun $saved.CmMalware -PinCommand $cmPinCmd -SamplePath $sample
    Write-RunSummaryLog -Tag $tag -Knob $Countermeasure -BaselineMalware $saved.BaseMalware -CmMalware $saved.CmMalware `
        -BaselinePoc $saved.BaseMemscan -CmPoc $saved.CmMemscan -BaselineCounts $saved.BaseCounts -CmCounts $saved.CmCounts
    exit 0
}

Show-InvocationHeader -Sha256 $Sha256 -Knob $Countermeasure -ShowOnly:$false

Write-Host "Fluxo desta execucao (2 etapas):" -ForegroundColor Cyan
Write-Host "  [1] App de teste (evidencia no console)  : $(if ($pocExe) { $pocExe } else { '(omitido)' })"
if ($Loop1000) {
    Write-Host "      -> variante Loop_X_1000 (1000 iteracoes para medir tempo)" -ForegroundColor Cyan
}
Write-Host "  [2] Amostra real (malware)               : $sample"
Write-Host ""

$pocTimeout = Get-PocTimeout -Knob $Countermeasure -Loop1000:$Loop1000
$pocBaseKnobs = Get-PocBaselineKnobs -Knob $Countermeasure
$pocCmKnobs = Get-PocCmKnobs -Knob $Countermeasure -SignatureFile $SignatureFile
$usesMemscan = Test-CmUsesMemscan -Knob $Countermeasure

if (-not $SkipMemscan) {
    Write-Host "[1/2] Executando app de teste (baseline e -$Countermeasure)..." -ForegroundColor Yellow
    $baseMemscan = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe `
        -Knobs $pocBaseKnobs -TimeoutSeconds $pocTimeout -Scenario "testapp_baseline_$Countermeasure" `
        -ProgressLabel "app teste baseline"
    $baseCounts = if ($usesMemscan) { Parse-MemscanCounts -Stdout $baseMemscan.Stdout } else { $null }

    $cmMemscan = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe `
        -Knobs $pocCmKnobs -TimeoutSeconds $pocTimeout -Scenario "testapp_$Countermeasure" `
        -ProgressLabel "app teste -$Countermeasure"
    $cmCounts = if ($usesMemscan) { Parse-MemscanCounts -Stdout $cmMemscan.Stdout } else { $null }
}
else {
    $baseCounts = $null
    $cmCounts = $null
    $baseMemscan = [PSCustomObject]@{ Seconds = 0; Outcome = "skipped"; Stdout = "" }
    $cmMemscan = [PSCustomObject]@{ Seconds = 0; Outcome = "skipped"; Stdout = "" }
}

Write-Host "[2/2] Executando amostra real (malware) (baseline e -$Countermeasure)..." -ForegroundColor Yellow
$baseMalware = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $toolDll -SamplePath $sample `
    -Knobs @() -FollowChild:$FollowChild -TimeoutSeconds $TimeoutSeconds -Scenario "pin_baseline" `
    -ProgressLabel "amostra real baseline"

$cmMalware = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $toolDll -SamplePath $sample `
    -Knobs $cmKnobs -FollowChild:$FollowChild -TimeoutSeconds $TimeoutSeconds -Scenario "pin_$Countermeasure" `
    -ProgressLabel "amostra real -$Countermeasure"

$basePinCmd = Get-PinCommandFromRun -Run $baseMemscan -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe -Knobs $pocBaseKnobs
$cmPinCmd = Get-PinCommandFromRun -Run $cmMemscan -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe -Knobs $pocCmKnobs

Show-BaselineReport -Knob $Countermeasure -PocRun $baseMemscan -Counts $baseCounts -MalwareRun $baseMalware -PinCommand $basePinCmd -SamplePath $sample
Show-CmReport -Knob $Countermeasure -PocRun $cmMemscan -Counts $cmCounts -MalwareRun $cmMalware -PinCommand $cmPinCmd -SamplePath $sample
Write-RunSummaryLog -Tag $tag -Knob $Countermeasure -BaselineMalware $baseMalware -CmMalware $cmMalware `
    -BaselinePoc $baseMemscan -CmPoc $cmMemscan -BaselineCounts $baseCounts -CmCounts $cmCounts

Save-RunArtifacts -Tag $tag -Knob $Countermeasure -BaselineMalware $baseMalware -CmMalware $cmMalware `
    -BaselineMemscan $baseMemscan -CmMemscan $cmMemscan -BaselineCounts $baseCounts -CmCounts $cmCounts
