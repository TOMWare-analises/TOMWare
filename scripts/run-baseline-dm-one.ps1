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

.EXAMPLE
    .\scripts\run-baseline-dm-one.ps1 -Sha256 6ED8D67BBDCE80D1B2A5FD3209CBAEA66B9B893F9412DD1E9FF03829F108400D -Countermeasure dm -SampleType benign

.EXAMPLE
    .\scripts\run-baseline-dm-one.ps1 -Sha256 6ED8D67B... -SampleType benign -AllCountermeasures
#>
[CmdletBinding()]
param(
    [ValidatePattern("^[A-Fa-f0-9]{64}$")]
    [string]$Sha256 = "0e3e95ee6649238171fb409c143c8a944bc54332f0ce85b94c651b5d0bf95343",
    [ValidateSet("de", "dm", "do", "dd", "dp", "da")]
    [string]$Countermeasure = "dm",
    [ValidateSet("infected", "benign")]
    [string]$SampleType = "infected",
    [string]$SamplesDir,
    [string]$SignatureFile = "config/signatures.txt",
    [int]$TimeoutSeconds = 120,
    [ValidateRange(1, 120)]
    [int]$SampleObservationSeconds = 10,
    [int]$MemscanTimeoutSeconds = 120,
    [bool]$FollowChild = $true,
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [switch]$ShowOnly,
    [switch]$SkipMemscan,
    [switch]$Loop1000,
    [ValidateRange(1, 10)]
    [int]$Repeat = 10,
    [switch]$AllCountermeasures,
    [ValidateSet("de", "dm", "do", "dd", "dp")]
    [string]$StartFrom = "de"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot
. (Join-Path $repoRoot "scripts/lib/TomwareBenchmark.ps1")

# Preserva a evidência completa no CMD clássico. O comando
# "mode con ... lines=58" reduz o histórico e impede rolar até resultados anteriores.
try {
    $rawUi = $Host.UI.RawUI
    $currentBuffer = $rawUi.BufferSize
    $desiredWidth = [Math]::Max($currentBuffer.Width, 140)
    $desiredHeight = [Math]::Max($currentBuffer.Height, 9999)
    $rawUi.BufferSize = New-Object System.Management.Automation.Host.Size($desiredWidth, $desiredHeight)
}
catch {
    Write-Verbose "Nao foi possivel ampliar o buffer do console: $($_.Exception.Message)"
}

if ([string]::IsNullOrWhiteSpace($SamplesDir)) {
    $SamplesDir = Join-Path "C:\TOMWare\malwares" $SampleType
}
elseif (-not [System.IO.Path]::IsPathRooted($SamplesDir)) {
    $SamplesDir = Join-Path $repoRoot $SamplesDir
}

$script:sampleTypeLabel = $SampleType

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

    if ($MalwareRun.RepeatCount -gt 1 -and $MalwareRun.Statistics) {
        $s = $MalwareRun.Statistics
        $prefix = if ($functionalOnly) { "evidencia funcional = caixa acima | " } else { "" }
        return ("    Result  : {0}validas={1}/{2} (complete={3}, observed={4}) | media={5}s | mediana={6}s | p95={7}s | desvio={8}s" -f `
            $prefix, $s.Valid, $s.Attempted, $s.Complete, $s.Observed, `
            $s.MeanSeconds, $s.MedianSeconds, $s.P95Seconds, $s.StdDevSeconds)
    }

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

function Get-FunctionalEvidenceResult {
    param(
        [string]$Knob,
        [object]$BaselinePoc,
        [object]$CmPoc,
        [object]$BaselineCounts,
        [object]$CmCounts
    )

    $cfg = Get-PocConfig -Knob $Knob
    $question = "A contramedida ocultou o Pin?"
    $baselineHighlights = @(Get-PocHighlightLines -Stdout $BaselinePoc.Stdout)
    $cmHighlights = @(Get-PocHighlightLines -Stdout $CmPoc.Stdout)
    $baselineDetected = $false
    $cmMasked = $false

    if ($BaselinePoc.Outcome -ne "skipped" -and $CmPoc.Outcome -ne "skipped") {
        $baselineDetected = Test-PocDetect -Knob $Knob -PocRun $BaselinePoc `
            -Counts $BaselineCounts -IsBaseline $true
        $cmMasked = Test-PocDetect -Knob $Knob -PocRun $CmPoc `
            -Counts $CmCounts -IsBaseline $false
    }

    $status = if ($BaselinePoc.Outcome -eq "skipped" -or $CmPoc.Outcome -eq "skipped") {
        "SKIPPED"
    }
    elseif ($baselineDetected -and $cmMasked) {
        "PASS"
    }
    elseif (-not $baselineDetected) {
        "INCONCLUSIVE"
    }
    elseif ($CmPoc.Outcome -in @("timeout", "error", "early_exit")) {
        "INCONCLUSIVE"
    }
    else {
        "FAIL"
    }

    $answer = switch ($status) {
        "PASS" {
            "Sim. O PoC detectou o Pin no baseline e confirmou a ocultacao com -$Knob."
        }
        "FAIL" {
            "Nao. O PoC detectou o Pin no baseline, mas o vestigio permaneceu com -$Knob."
        }
        "SKIPPED" {
            "Nao avaliado: o app de teste funcional foi omitido."
        }
        default {
            "Inconclusivo: o PoC nao produziu evidencias suficientes para validar baseline e -$Knob."
        }
    }

    $evidenceSummary = if ($cfg.UsesMemscan) {
        "PIN_: baseline=$($BaselineCounts.PIN_), -$Knob=$($CmCounts.PIN_); " +
        "pin.exe: baseline=$($BaselineCounts.pin_exe), -$Knob=$($CmCounts.pin_exe); " +
        "pinvm.dll: baseline=$($BaselineCounts.pinvm_dll), -$Knob=$($CmCounts.pinvm_dll); " +
        "pinipc.dll: baseline=$($BaselineCounts.pinipc_dll), -$Knob=$($CmCounts.pinipc_dll)"
    }
    else {
        "baseline: $($baselineHighlights -join ' | '); -$Knob`: $($cmHighlights -join ' | ')"
    }

    return [PSCustomObject]@{
        Question                 = $question
        Status                   = $status
        Answer                   = $answer
        Proves                   = $CmProvesRef[$Knob].Proves
        BaselineDetectedPin      = [bool]$baselineDetected
        CountermeasureMaskedPin  = [bool]$cmMasked
        EvidenceSummary          = $evidenceSummary
        Baseline                 = [PSCustomObject]@{
            Outcome    = $BaselinePoc.Outcome
            Seconds    = $BaselinePoc.Seconds
            Highlights = $baselineHighlights
            Counts     = $BaselineCounts
        }
        Countermeasure          = [PSCustomObject]@{
            Outcome    = $CmPoc.Outcome
            Seconds    = $CmPoc.Seconds
            Highlights = $cmHighlights
            Counts     = $CmCounts
        }
    }
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

    $deltaLine = if ($Repeat -gt 1) {
        "  delta (-$Knob - base) : ver relatorio benchmark JSON/CSV (comparacao pareada por rodada)"
    }
    elseif ($quantOk) {
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
        "  $script:sampleTypeLabel baseline : skipped"
    }
    elseif ($baseOk -and -not $functionalOnly) {
        ("  {0} baseline : {1}s | outcome={2}" -f $script:sampleTypeLabel, $BaselineMalware.Seconds, $BaselineMalware.Outcome)
    }
    elseif ($functionalOnly) {
        ("  {0} baseline : outcome={1} (executada; tempo nao e metrica de -{2})" -f $script:sampleTypeLabel, $BaselineMalware.Outcome, $Knob)
    }
    else {
        ("  {0} baseline : outcome={1} (tempo nao quantitativo; wall={2}s)" -f $script:sampleTypeLabel, $BaselineMalware.Outcome, $BaselineMalware.Seconds)
    }

    $cmLine = if ($CmMalware.Outcome -eq "skipped") {
        "  $script:sampleTypeLabel -$Knob      : skipped"
    }
    elseif ($cmOk -and -not $functionalOnly) {
        ("  {0} -{1}      : {2}s | outcome={3}" -f $script:sampleTypeLabel, $Knob, $CmMalware.Seconds, $CmMalware.Outcome)
    }
    elseif ($functionalOnly) {
        ("  {0} -{1}      : outcome={2} (executada; tempo nao e metrica de -{1})" -f $script:sampleTypeLabel, $Knob, $CmMalware.Outcome)
    }
    else {
        ("  {0} -{1}      : outcome={2} (tempo nao quantitativo; wall={3}s)" -f $script:sampleTypeLabel, $Knob, $CmMalware.Outcome, $CmMalware.Seconds)
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
            $(if ($BaselineCounts -and $null -ne $BaselineCounts.PIN_) { $BaselineCounts.PIN_ } else { "n/a" }), `
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
        "$script:sampleTypeLabel sample: $([math]::Round($baseSec,1))s -> $([math]::Round($cmSec,1))s."
    }
    elseif (Test-CmFunctionalOnly -Knob $Knob) {
        "Real sample exercised; runtime is not a -dp effectiveness metric."
    }
    else {
        "$script:sampleTypeLabel sample timing discarded (outcome not complete)."
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
            return @{ Status = "OK"; Color = "Green"; Reason = "$($cfg.Module) effective: vestige masked. $script:sampleTypeLabel sample: $([math]::Round($baseSec,1))s -> $([math]::Round($cmSec,1))s (+$([math]::Round($delta,1))s)." }
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

    $safeBaseline = Get-JsonSafeRun $BaselineMalware
    $safeCm = Get-JsonSafeRun $CmMalware
    $safeBasePoc = Get-JsonSafeRun $BaselineMemscan
    $safeCmPoc = Get-JsonSafeRun $CmMemscan

    $safeBaseline | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $outDir "baseline-$Tag.json") -Encoding UTF8
    $safeCm | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $outDir "$Knob-$Tag.json") -Encoding UTF8
    @{ Run = $safeBasePoc; Counts = $BaselineCounts } | ConvertTo-Json -Depth 6 |
        Set-Content -Path (Join-Path $outDir "memscan-baseline.json") -Encoding UTF8
    if (Test-CmUsesMemscan -Knob $Knob) {
        @{ Run = $safeCmPoc; Counts = $CmCounts } | ConvertTo-Json -Depth 6 |
            Set-Content -Path (Join-Path $outDir "memscan-$Knob.json") -Encoding UTF8
    }
    @{
        Sha256          = $Sha256
        SampleType      = $SampleType
        SamplesDir      = $SamplesDir
        SamplePath      = $sample
        Countermeasure  = $Knob
        UsesMemscan     = (Test-CmUsesMemscan -Knob $Knob)
        Knobs           = (Get-CountermeasureKnobs -Knob $Knob -SignatureFile $SignatureFile)
        BaselineMalware = $safeBaseline
        CmMalware       = $safeCm
        BaselineMemscan = $safeBasePoc
        CmMemscan       = $safeCmPoc
        BaselineCounts  = $BaselineCounts
        CmCounts        = $CmCounts
    } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $outDir "baseline-$Knob-$Tag.json") -Encoding UTF8
}

function Assert-SavedCountermeasure {
    param(
        [object]$Saved,
        [string]$Knob
    )
    if ($Saved.Countermeasure -and $Saved.Countermeasure -ne $Knob) {
        throw "Saved data is for -$($Saved.Countermeasure), not -$Knob. Run without -ShowOnly first."
    }
    if ($Saved.SampleType -and $Saved.SampleType -ne $SampleType) {
        throw "Saved data is for sample type '$($Saved.SampleType)', not '$SampleType'. Run without -ShowOnly first."
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
            BaseCounts  = $saved.BaselineCounts
            CmCounts    = if ($saved.CmCounts) { $saved.CmCounts } else { $null }
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
                BaseCounts  = $saved.BaselineCounts
                CmCounts    = if ($saved.CmCounts) { $saved.CmCounts } else { $saved.DmCounts }
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

function Stop-ResidualSampleProcesses {
    param([string]$SamplePath)

    $resolvedSample = $null
    try {
        $resolvedSample = (Resolve-Path -LiteralPath $SamplePath -ErrorAction Stop).Path
    }
    catch {
        return $true
    }

    $sampleLeaf = [System.IO.Path]::GetFileName($resolvedSample)
    try {
        $processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            (
                $_.ExecutablePath -and $_.ExecutablePath -ieq $resolvedSample
            ) -or (
                $sampleLeaf -and $_.Name -and ($_.Name -ieq $sampleLeaf)
            ) -or (
                $_.CommandLine -and (
                    $_.CommandLine -like "*$resolvedSample*" -or
                    $_.CommandLine -like "*\$sampleLeaf*"
                ) -and (
                    $_.Name -match '^(pin|pin\.exe)$'
                )
            )
        })
        foreach ($process in $processes) {
            try {
                Invoke-CimMethod -InputObject $process -MethodName Terminate -ErrorAction SilentlyContinue | Out-Null
            }
            catch { }
            try {
                Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
            }
            catch { }
        }
        if ($processes.Count -gt 0) {
            Start-Sleep -Milliseconds 400
        }
        $remaining = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            ($_.ExecutablePath -and $_.ExecutablePath -ieq $resolvedSample) -or
            ($sampleLeaf -and $_.Name -and ($_.Name -ieq $sampleLeaf))
        })
        return ($remaining.Count -eq 0)
    }
    catch {
        Write-Warning "Could not verify residual sample processes: $($_.Exception.Message)"
        return $false
    }
}

function Get-JsonSafeNumber {
    param($Value)
    if ($null -eq $Value) { return $null }
    try {
        $number = [double]$Value
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) { return $null }
        return $number
    }
    catch {
        return $null
    }
}

function Get-JsonSafeRun {
    param([object]$Run)
    if (-not $Run) { return $null }
    $metrics = $null
    if ($Run.ResourceMetrics) {
        $metrics = [PSCustomObject]@{
            Available                 = [bool]$Run.ResourceMetrics.Available
            SamplingIntervalMs        = $Run.ResourceMetrics.SamplingIntervalMs
            SampleCount               = $Run.ResourceMetrics.SampleCount
            TrackedProcessPeak        = $Run.ResourceMetrics.TrackedProcessPeak
            CpuSeconds                = (Get-JsonSafeNumber $Run.ResourceMetrics.CpuSeconds)
            CpuPercentOneCore         = (Get-JsonSafeNumber $Run.ResourceMetrics.CpuPercentOneCore)
            CpuPercentTotalCapacity   = (Get-JsonSafeNumber $Run.ResourceMetrics.CpuPercentTotalCapacity)
            AverageWorkingSetMB       = (Get-JsonSafeNumber $Run.ResourceMetrics.AverageWorkingSetMB)
            PeakWorkingSetMB          = (Get-JsonSafeNumber $Run.ResourceMetrics.PeakWorkingSetMB)
            PeakPrivateMemoryMB       = (Get-JsonSafeNumber $Run.ResourceMetrics.PeakPrivateMemoryMB)
        }
    }
    return [PSCustomObject]@{
        Scenario         = $Run.Scenario
        ExitCode         = $Run.ExitCode
        Seconds          = (Get-JsonSafeNumber $Run.Seconds)
        TimedOut         = [bool]$Run.TimedOut
        Outcome          = $Run.Outcome
        Stdout           = [string]$Run.Stdout
        Stderr           = [string]$Run.Stderr
        Command          = [string]$Run.Command
        ObservationCompleted = [bool]$Run.ObservationCompleted
        ObservationSeconds   = $Run.ObservationSeconds
        RepeatCount      = $Run.RepeatCount
        Statistics       = $Run.Statistics
        ResourceMetrics  = $metrics
    }
}

function Invoke-BenchmarkSampleRun {
    param(
        [string]$PinExe,
        [string]$ToolDll,
        [string]$SamplePath,
        [string[]]$Knobs,
        [bool]$FollowChild,
        [int]$TimeoutSeconds,
        [int]$ObservationSeconds,
        [string]$Scenario,
        [string]$ProgressLabel
    )

    # A janela curta funciona para CLI e GUI: processos que encerram antes dela
    # preservam o outcome normal; processos persistentes viram "observed".
    $effectiveTimeout = [Math]::Min($TimeoutSeconds, $ObservationSeconds)
    $run = Invoke-TomwarePinRun -PinExe $PinExe -ToolDll $ToolDll -SamplePath $SamplePath `
        -Knobs $Knobs -FollowChild:$FollowChild -TimeoutSeconds $effectiveTimeout `
        -Scenario $Scenario -ProgressLabel $ProgressLabel

    if ($run.Outcome -eq "timeout" -and $effectiveTimeout -eq $ObservationSeconds) {
        $cleanupSucceeded = Stop-ResidualSampleProcesses -SamplePath $SamplePath
        if ($cleanupSucceeded) {
            $run.Outcome = "observed"
            $run.TimedOut = $false
            $run.ExitCode = $null
            $run | Add-Member -NotePropertyName ObservationCompleted -NotePropertyValue $true -Force
            $run | Add-Member -NotePropertyName ObservationSeconds -NotePropertyValue $ObservationSeconds -Force
            Write-Host ("    janela de observacao concluida: {0}s ({1})" -f $ObservationSeconds, $ProgressLabel) -ForegroundColor DarkGray
        }
        else {
            Write-Warning "Sample process remained active after observation window; keeping outcome=timeout."
        }
    }

    return $run
}

function Get-Percentile {
    param(
        [double[]]$Values,
        [ValidateRange(0.0, 1.0)]
        [double]$Percentile
    )

    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 1) { return [Math]::Round([double]$sorted[0], 3) }

    $position = ($sorted.Count - 1) * $Percentile
    $lower = [Math]::Floor($position)
    $upper = [Math]::Ceiling($position)
    if ($lower -eq $upper) { return [Math]::Round([double]$sorted[$lower], 3) }

    $weight = $position - $lower
    $value = ([double]$sorted[$lower] * (1.0 - $weight)) + ([double]$sorted[$upper] * $weight)
    return [Math]::Round($value, 3)
}

function Get-RunStatistics {
    param([object[]]$Runs)

    $allRuns = @($Runs)
    $completeRuns = @($allRuns | Where-Object { $_.Outcome -eq "complete" })
    $observedRuns = @($allRuns | Where-Object { $_.Outcome -eq "observed" })
    $validRuns = @($allRuns | Where-Object { $_.Outcome -in @("complete", "observed") })
    $values = @($validRuns | ForEach-Object { [double]$_.Seconds })

    $mean = $null
    $median = $null
    $p95 = $null
    $minimum = $null
    $maximum = $null
    $stdDev = $null

    if ($values.Count -gt 0) {
        $rawMean = [double](($values | Measure-Object -Average).Average)
        $mean = [Math]::Round($rawMean, 3)
        $median = Get-Percentile -Values $values -Percentile 0.5
        $p95 = Get-Percentile -Values $values -Percentile 0.95
        $minimum = [Math]::Round([double](($values | Measure-Object -Minimum).Minimum), 3)
        $maximum = [Math]::Round([double](($values | Measure-Object -Maximum).Maximum), 3)

        if ($values.Count -gt 1) {
            $sumSquares = 0.0
            foreach ($value in $values) {
                $sumSquares += [Math]::Pow(([double]$value - $rawMean), 2)
            }
            $stdDev = [Math]::Round([Math]::Sqrt($sumSquares / ($values.Count - 1)), 3)
        }
        else {
            $stdDev = 0.0
        }
    }

    return [PSCustomObject]@{
        Attempted    = $allRuns.Count
        Complete     = $completeRuns.Count
        Observed     = $observedRuns.Count
        Valid        = $validRuns.Count
        Timeout      = @($allRuns | Where-Object { $_.Outcome -eq "timeout" }).Count
        EarlyExit    = @($allRuns | Where-Object { $_.Outcome -eq "early_exit" }).Count
        Error        = @($allRuns | Where-Object { $_.Outcome -eq "error" }).Count
        Other        = @($allRuns | Where-Object { $_.Outcome -notin @("complete", "observed", "timeout", "early_exit", "error") }).Count
        MeanSeconds  = $mean
        MedianSeconds = $median
        P95Seconds   = $p95
        StdDevSeconds = $stdDev
        MinSeconds   = $minimum
        MaxSeconds   = $maximum
    }
}

function Get-MetricStatistics {
    param([double[]]$Values)

    $items = @($Values | Where-Object {
        $null -ne $_ -and -not [double]::IsNaN([double]$_) -and -not [double]::IsInfinity([double]$_)
    })
    if ($items.Count -eq 0) {
        return [PSCustomObject]@{
            Count = 0; Mean = $null; Median = $null; P95 = $null
            StdDev = $null; Min = $null; Max = $null
        }
    }

    $rawMean = [double](($items | Measure-Object -Average).Average)
    $stdDev = 0.0
    if ($items.Count -gt 1) {
        $sumSquares = 0.0
        foreach ($value in $items) {
            $sumSquares += [Math]::Pow(([double]$value - $rawMean), 2)
        }
        $stdDev = [Math]::Sqrt($sumSquares / ($items.Count - 1))
    }

    return [PSCustomObject]@{
        Count  = $items.Count
        Mean   = [Math]::Round($rawMean, 3)
        Median = Get-Percentile -Values $items -Percentile 0.5
        P95    = Get-Percentile -Values $items -Percentile 0.95
        StdDev = [Math]::Round($stdDev, 3)
        Min    = [Math]::Round([double](($items | Measure-Object -Minimum).Minimum), 3)
        Max    = [Math]::Round([double](($items | Measure-Object -Maximum).Maximum), 3)
    }
}

function Get-ResourceStatistics {
    param([object[]]$Runs)

    $availableRuns = @($Runs | Where-Object { $_.ResourceMetrics -and $_.ResourceMetrics.Available })
    return [PSCustomObject]@{
        Attempted             = @($Runs).Count
        Available             = $availableRuns.Count
        CpuSeconds            = Get-MetricStatistics -Values @(
            $availableRuns | ForEach-Object { [double]$_.ResourceMetrics.CpuSeconds }
        )
        CpuPercentOneCore     = Get-MetricStatistics -Values @(
            $availableRuns | ForEach-Object { [double]$_.ResourceMetrics.CpuPercentOneCore }
        )
        AverageWorkingSetMB   = Get-MetricStatistics -Values @(
            $availableRuns | ForEach-Object { [double]$_.ResourceMetrics.AverageWorkingSetMB }
        )
        PeakWorkingSetMB      = Get-MetricStatistics -Values @(
            $availableRuns | ForEach-Object { [double]$_.ResourceMetrics.PeakWorkingSetMB }
        )
        PeakPrivateMemoryMB   = Get-MetricStatistics -Values @(
            $availableRuns | ForEach-Object { [double]$_.ResourceMetrics.PeakPrivateMemoryMB }
        )
    }
}

function Get-PairedResourceStatistics {
    param(
        [object[]]$BaselineRuns,
        [object[]]$CountermeasureRuns
    )

    $attemptedPairs = [Math]::Min($BaselineRuns.Count, $CountermeasureRuns.Count)
    $cpuDeltas = @()
    $cpuPercents = @()
    $workingSetDeltas = @()
    $workingSetPercents = @()
    $privateDeltas = @()
    $validPairs = 0

    for ($index = 0; $index -lt $attemptedPairs; $index++) {
        $baselineMetrics = $BaselineRuns[$index].ResourceMetrics
        $cmMetrics = $CountermeasureRuns[$index].ResourceMetrics
        if (-not $baselineMetrics -or -not $cmMetrics -or
            -not $baselineMetrics.Available -or -not $cmMetrics.Available) {
            continue
        }

        $validPairs++
        $cpuDeltas += [double]$cmMetrics.CpuSeconds - [double]$baselineMetrics.CpuSeconds
        $workingSetDeltas += [double]$cmMetrics.PeakWorkingSetMB - [double]$baselineMetrics.PeakWorkingSetMB
        $privateDeltas += [double]$cmMetrics.PeakPrivateMemoryMB - [double]$baselineMetrics.PeakPrivateMemoryMB
        if ([double]$baselineMetrics.CpuSeconds -gt 0) {
            $cpuPercents += (([double]$cmMetrics.CpuSeconds / [double]$baselineMetrics.CpuSeconds) - 1.0) * 100.0
        }
        if ([double]$baselineMetrics.PeakWorkingSetMB -gt 0) {
            $workingSetPercents += (([double]$cmMetrics.PeakWorkingSetMB / [double]$baselineMetrics.PeakWorkingSetMB) - 1.0) * 100.0
        }
    }

    return [PSCustomObject]@{
        AttemptedPairs              = $attemptedPairs
        ValidPairs                  = $validPairs
        AllPairsValid               = (
            $attemptedPairs -gt 0 -and
            $BaselineRuns.Count -eq $CountermeasureRuns.Count -and
            $validPairs -eq $attemptedPairs
        )
        CpuDeltaSeconds             = Get-MetricStatistics -Values $cpuDeltas
        CpuChangePercent            = Get-MetricStatistics -Values $cpuPercents
        PeakWorkingSetDeltaMB       = Get-MetricStatistics -Values $workingSetDeltas
        PeakWorkingSetChangePercent = Get-MetricStatistics -Values $workingSetPercents
        PeakPrivateMemoryDeltaMB    = Get-MetricStatistics -Values $privateDeltas
    }
}

function Get-PairedRunStatistics {
    param(
        [object[]]$BaselineRuns,
        [object[]]$CountermeasureRuns
    )

    $attemptedPairs = [Math]::Min($BaselineRuns.Count, $CountermeasureRuns.Count)
    $deltaRuns = @()
    $percentRuns = @()
    for ($index = 0; $index -lt $attemptedPairs; $index++) {
        $baseline = $BaselineRuns[$index]
        $countermeasure = $CountermeasureRuns[$index]
        if ($baseline.Outcome -eq "complete" -and $countermeasure.Outcome -eq "complete") {
            $deltaRuns += [PSCustomObject]@{
                Seconds = [double]$countermeasure.Seconds - [double]$baseline.Seconds
                Outcome = "complete"
            }
            if ([double]$baseline.Seconds -gt 0) {
                $percentRuns += [PSCustomObject]@{
                    Seconds = (([double]$countermeasure.Seconds / [double]$baseline.Seconds) - 1.0) * 100.0
                    Outcome = "complete"
                }
            }
        }
    }

    $stats = Get-RunStatistics -Runs $deltaRuns
    $percentStats = Get-RunStatistics -Runs $percentRuns
    return [PSCustomObject]@{
        AttemptedPairs     = $attemptedPairs
        ValidPairs         = $deltaRuns.Count
        AllPairsValid      = (
            $attemptedPairs -gt 0 -and
            $BaselineRuns.Count -eq $CountermeasureRuns.Count -and
            $deltaRuns.Count -eq $attemptedPairs
        )
        MeanDeltaSeconds   = $stats.MeanSeconds
        MedianDeltaSeconds = $stats.MedianSeconds
        P95DeltaSeconds    = $stats.P95Seconds
        StdDevDeltaSeconds = $stats.StdDevSeconds
        MinDeltaSeconds    = $stats.MinSeconds
        MaxDeltaSeconds    = $stats.MaxSeconds
        MeanChangePercent  = $percentStats.MeanSeconds
        MedianChangePercent = $percentStats.MedianSeconds
        P95ChangePercent   = $percentStats.P95Seconds
    }
}

function New-AggregateRun {
    param(
        [object[]]$Runs,
        [string]$Scenario
    )

    $stats = Get-RunStatistics -Runs $Runs
    $outcome = if ($stats.Valid -eq $stats.Attempted) {
        if ($stats.Observed -gt 0) { "observed" } else { "complete" }
    }
    elseif ($stats.Valid -gt 0) {
        "partial"
    }
    elseif ($stats.Timeout -eq $stats.Attempted) {
        "timeout"
    }
    elseif ($stats.EarlyExit -eq $stats.Attempted) {
        "early_exit"
    }
    else {
        "error"
    }
    return [PSCustomObject]@{
        Scenario     = $Scenario
        ExitCode     = $null
        Seconds      = $stats.MedianSeconds
        TimedOut     = ($stats.Timeout -gt 0)
        Outcome      = $outcome
        Stdout       = ""
        Stderr       = ""
        Command      = "aggregate of $($stats.Attempted) independent runs"
        RepeatCount  = $stats.Attempted
        Statistics   = $stats
    }
}

function Save-BenchmarkReports {
    param(
        [string]$Knob,
        [string]$Tag,
        [object[]]$BaselineRuns,
        [object[]]$CountermeasureRuns,
        [object[]]$Rows,
        [object]$BaselinePoc,
        [object]$CountermeasurePoc,
        [object]$BaselineCounts,
        [object]$CountermeasureCounts
    )

    $outDir = Join-Path $repoRoot "Resultados\benchmarks"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $prefix = "benchmark-$SampleType-$Knob-$Tag-$timestamp"
    $csvPath = Join-Path $outDir "$prefix.csv"
    $jsonPath = Join-Path $outDir "$prefix.json"

    $baselineStats = Get-RunStatistics -Runs $BaselineRuns
    $countermeasureStats = Get-RunStatistics -Runs $CountermeasureRuns
    $pairedStats = Get-PairedRunStatistics -BaselineRuns $BaselineRuns -CountermeasureRuns $CountermeasureRuns
    $baselineResourceStats = Get-ResourceStatistics -Runs $BaselineRuns
    $countermeasureResourceStats = Get-ResourceStatistics -Runs $CountermeasureRuns
    $pairedResourceStats = Get-PairedResourceStatistics `
        -BaselineRuns $BaselineRuns -CountermeasureRuns $CountermeasureRuns
    $functionalOnly = Test-CmFunctionalOnly -Knob $Knob
    $hasObservedRuns = (($baselineStats.Observed + $countermeasureStats.Observed) -gt 0)
    $comparisonValid = (-not $functionalOnly) -and $pairedStats.AllPairsValid -and (-not $hasObservedRuns)
    $comparisonReason = if ($functionalOnly) {
        "functional-only countermeasure; durations are reported but not used as an effectiveness metric"
    }
    elseif ($hasObservedRuns) {
        "fixed observation window used; total runtime is not a valid performance metric"
    }
    elseif (-not $pairedStats.AllPairsValid) {
        "comparison invalid: one or more baseline/countermeasure pairs did not complete"
    }
    else {
        "valid paired comparison"
    }
    $medianDelta = if ($comparisonValid) { $pairedStats.MedianDeltaSeconds } else { $null }
    $medianPercent = if ($comparisonValid) { $pairedStats.MedianChangePercent } else { $null }
    $functionalEvidence = Get-FunctionalEvidenceResult -Knob $Knob `
        -BaselinePoc $BaselinePoc -CmPoc $CountermeasurePoc `
        -BaselineCounts $BaselineCounts -CmCounts $CountermeasureCounts
    $resourceComparisonValid = $pairedResourceStats.AllPairsValid
    $performanceStatus = if ($comparisonValid -or $resourceComparisonValid) { "VALID" } else { "INCONCLUSIVE" }
    $resourceAnswer = if ($resourceComparisonValid) {
        $cpuBase = $baselineResourceStats.CpuSeconds.Median
        $cpuCm = $countermeasureResourceStats.CpuSeconds.Median
        $cpuDelta = $pairedResourceStats.CpuDeltaSeconds.Median
        $cpuPercent = $pairedResourceStats.CpuChangePercent.Median
        $wsBase = $baselineResourceStats.PeakWorkingSetMB.Median
        $wsCm = $countermeasureResourceStats.PeakWorkingSetMB.Median
        $wsDelta = $pairedResourceStats.PeakWorkingSetDeltaMB.Median
        $wsPercent = $pairedResourceStats.PeakWorkingSetChangePercent.Median
        "Recursos na janela: CPU mediana $cpuBase -> $cpuCm s (delta $cpuDelta s; $cpuPercent%); " +
        "pico de memoria $wsBase -> $wsCm MB (delta $wsDelta MB; $wsPercent%)."
    }
    else {
        "Metricas de CPU/memoria indisponiveis ou incompletas."
    }
    $performanceAnswer = if ($comparisonValid) {
        "Tempo total: impacto mediano de $medianDelta s ($medianPercent%) em comparacao pareada. $resourceAnswer"
    }
    elseif ($resourceComparisonValid) {
        "$resourceAnswer O tempo total permanece invalido: $comparisonReason."
    }
    else {
        "Nao foi possivel medir o impacto no desempenho: $comparisonReason. $resourceAnswer"
    }
    $performanceAssessment = [PSCustomObject]@{
        Question            = "Qual foi o impacto no desempenho?"
        Status              = $performanceStatus
        Answer              = $performanceAnswer
        Basis               = if ($comparisonValid -and $resourceComparisonValid) {
            "runtime and resource usage"
        }
        elseif ($comparisonValid) {
            "runtime"
        }
        elseif ($resourceComparisonValid) {
            "fixed-window resource usage"
        }
        else {
            "unavailable"
        }
        ComparisonValid     = $comparisonValid
        ComparisonReason    = $comparisonReason
        ResourceComparisonValid = $resourceComparisonValid
        Baseline            = $baselineStats
        Countermeasure      = $countermeasureStats
        PairedEffect        = $pairedStats
        BaselineResources   = $baselineResourceStats
        CountermeasureResources = $countermeasureResourceStats
        PairedResourceEffect = $pairedResourceStats
        MedianDeltaSeconds  = $medianDelta
        MedianChangePercent = $medianPercent
    }

    foreach ($row in $Rows) {
        $row | Add-Member -NotePropertyName ComparisonValid -NotePropertyValue $comparisonValid -Force
        $row | Add-Member -NotePropertyName ComparisonReason -NotePropertyValue $comparisonReason -Force
        $row | Add-Member -NotePropertyName FunctionalStatus -NotePropertyValue $functionalEvidence.Status -Force
        $row | Add-Member -NotePropertyName FunctionalAnswer -NotePropertyValue $functionalEvidence.Answer -Force
        $row | Add-Member -NotePropertyName FunctionalEvidence -NotePropertyValue $functionalEvidence.EvidenceSummary -Force
        $row | Add-Member -NotePropertyName PocBaselineOutcome -NotePropertyValue $BaselinePoc.Outcome -Force
        $row | Add-Member -NotePropertyName PocCountermeasureOutcome -NotePropertyValue $CountermeasurePoc.Outcome -Force
        $row | Add-Member -NotePropertyName PerformanceStatus -NotePropertyValue $performanceStatus -Force
        $row | Add-Member -NotePropertyName PerformanceAnswer -NotePropertyValue $performanceAnswer -Force
        $row | Add-Member -NotePropertyName ResourceComparisonValid -NotePropertyValue $resourceComparisonValid -Force
    }
    $Rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    [PSCustomObject]@{
        GeneratedAt          = (Get-Date).ToString("o")
        Sha256               = $Sha256
        SampleType           = $SampleType
        SamplePath           = $sample
        Countermeasure       = $Knob
        Repeat               = $Repeat
        OrderPolicy          = "alternating baseline/countermeasure first"
        StatisticsBasis      = "scenario summaries include complete/observed runs; runtime effect requires matched natural completions"
        SampleObservationSeconds = $SampleObservationSeconds
        ComparisonValid      = $comparisonValid
        ComparisonReason     = $comparisonReason
        Baseline             = $baselineStats
        CountermeasureResult = $countermeasureStats
        PairedEffect         = $pairedStats
        BaselineResources    = $baselineResourceStats
        CountermeasureResources = $countermeasureResourceStats
        PairedResourceEffect = $pairedResourceStats
        MedianDeltaSeconds   = $medianDelta
        MedianChangePercent  = $medianPercent
        Answers              = [PSCustomObject]@{
            Functional  = $functionalEvidence
            Performance = $performanceAssessment
        }
        FunctionalEvidence   = $functionalEvidence
        PerformanceAssessment = $performanceAssessment
        Runs                 = @($Rows)
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

    return [PSCustomObject]@{
        CsvPath = $csvPath
        JsonPath = $jsonPath
        Baseline = $baselineStats
        CountermeasureResult = $countermeasureStats
        PairedEffect = $pairedStats
        ComparisonValid = $comparisonValid
        ComparisonReason = $comparisonReason
        ResourceComparisonValid = $resourceComparisonValid
        BaselineResources = $baselineResourceStats
        CountermeasureResources = $countermeasureResourceStats
        PairedResourceEffect = $pairedResourceStats
        MedianDeltaSeconds = $medianDelta
        MedianChangePercent = $medianPercent
        FunctionalEvidence = $functionalEvidence
        PerformanceAssessment = $performanceAssessment
    }
}

function Save-ConsolidatedBenchmarkReports {
    param(
        [object[]]$Reports,
        [string]$Tag
    )

    $outDir = Join-Path $repoRoot "Resultados\benchmarks"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $prefix = "benchmark-$SampleType-all-$Tag-$timestamp"
    $csvPath = Join-Path $outDir "$prefix.csv"
    $jsonPath = Join-Path $outDir "$prefix.json"

    $summaryRows = foreach ($report in $Reports) {
        [PSCustomObject]@{
            Sha256                       = $report.Sha256
            SampleType                   = $report.SampleType
            Countermeasure               = $report.Countermeasure
            FunctionalQuestion           = $report.Answers.Functional.Question
            FunctionalStatus             = $report.Answers.Functional.Status
            FunctionalAnswer             = $report.Answers.Functional.Answer
            FunctionalEvidence           = $report.Answers.Functional.EvidenceSummary
            BaselineDetectedPin           = $report.Answers.Functional.BaselineDetectedPin
            CountermeasureMaskedPin       = $report.Answers.Functional.CountermeasureMaskedPin
            PerformanceQuestion          = $report.Answers.Performance.Question
            PerformanceStatus            = $report.Answers.Performance.Status
            PerformanceAnswer            = $report.Answers.Performance.Answer
            PerformanceComparisonValid   = $report.ComparisonValid
            PerformanceComparisonReason  = $report.ComparisonReason
            ResourceComparisonValid      = $report.Answers.Performance.ResourceComparisonValid
            BaselineMeanSeconds           = $report.Baseline.MeanSeconds
            BaselineMedianSeconds         = $report.Baseline.MedianSeconds
            BaselineP95Seconds            = $report.Baseline.P95Seconds
            CountermeasureMeanSeconds     = $report.CountermeasureResult.MeanSeconds
            CountermeasureMedianSeconds   = $report.CountermeasureResult.MedianSeconds
            CountermeasureP95Seconds      = $report.CountermeasureResult.P95Seconds
            MedianDeltaSeconds            = $report.MedianDeltaSeconds
            MedianChangePercent           = $report.MedianChangePercent
            BaselineMedianCpuSeconds      = $report.BaselineResources.CpuSeconds.Median
            CountermeasureMedianCpuSeconds = $report.CountermeasureResources.CpuSeconds.Median
            MedianCpuDeltaSeconds         = $report.PairedResourceEffect.CpuDeltaSeconds.Median
            MedianCpuChangePercent        = $report.PairedResourceEffect.CpuChangePercent.Median
            BaselineMedianPeakWorkingSetMB = $report.BaselineResources.PeakWorkingSetMB.Median
            CountermeasureMedianPeakWorkingSetMB = $report.CountermeasureResources.PeakWorkingSetMB.Median
            MedianPeakWorkingSetDeltaMB   = $report.PairedResourceEffect.PeakWorkingSetDeltaMB.Median
            MedianPeakWorkingSetChangePercent = $report.PairedResourceEffect.PeakWorkingSetChangePercent.Median
            BaselineMedianPeakPrivateMemoryMB = $report.BaselineResources.PeakPrivateMemoryMB.Median
            CountermeasureMedianPeakPrivateMemoryMB = $report.CountermeasureResources.PeakPrivateMemoryMB.Median
            BaselineComplete              = $report.Baseline.Complete
            BaselineObserved              = $report.Baseline.Observed
            CountermeasureComplete        = $report.CountermeasureResult.Complete
            CountermeasureObserved        = $report.CountermeasureResult.Observed
        }
    }

    $summaryRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    [PSCustomObject]@{
        GeneratedAt = (Get-Date).ToString("o")
        Sha256       = $Sha256
        SampleType   = $SampleType
        SamplePath   = (Join-Path $SamplesDir "$Sha256.exe")
        Repeat       = $Repeat
        Questions    = [PSCustomObject]@{
            Functional  = "A contramedida ocultou o Pin?"
            Performance = "Qual foi o impacto no desempenho?"
        }
        Summary      = @($summaryRows)
        Countermeasures = @($Reports)
    } | ConvertTo-Json -Depth 12 | Set-Content -Path $jsonPath -Encoding UTF8

    return [PSCustomObject]@{
        CsvPath  = $csvPath
        JsonPath = $jsonPath
        Summary  = @($summaryRows)
    }
}

# --- main ---

if ($AllCountermeasures) {
    if ($ShowOnly) {
        throw "-AllCountermeasures cannot be combined with -ShowOnly."
    }
    if ($Repeat -lt 2) {
        throw "-AllCountermeasures requires -Repeat 2 or greater to generate statistical reports."
    }

    $countermeasures = @("de", "dm", "do", "dd", "dp")
    $startIndex = [Array]::IndexOf($countermeasures, $StartFrom)
    if ($startIndex -lt 0) {
        throw "Invalid -StartFrom value: $StartFrom"
    }
    $priorCountermeasures = @()
    if ($startIndex -gt 0) {
        $priorCountermeasures = @($countermeasures[0..($startIndex - 1)])
    }
    $countermeasures = @($countermeasures[$startIndex..($countermeasures.Count - 1)])

    $allReports = @()
    $allTag = $Sha256.Substring(0, 8)
    $benchmarkDir = Join-Path $repoRoot "Resultados\benchmarks"
    New-Item -ItemType Directory -Force -Path $benchmarkDir | Out-Null

    foreach ($priorKnob in $priorCountermeasures) {
        $priorJson = Get-ChildItem -Path $benchmarkDir `
            -Filter "benchmark-$SampleType-$priorKnob-$allTag-*.json" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if (-not $priorJson) {
            throw "Nao ha JSON previo de -$priorKnob em $benchmarkDir. Rode sem -StartFrom ou comece em -$priorKnob."
        }
        Write-Host ("Reusando relatorio previo -$priorKnob : {0}" -f $priorJson.Name) -ForegroundColor DarkGray
        $allReports += Get-Content $priorJson.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    Write-Host ""
    Write-Host "Benchmark completo: $Repeat repeticoes para cada contramedida." -ForegroundColor Cyan
    Write-Host "Ordem por rodada alternada para reduzir vies de aquecimento/deriva." -ForegroundColor DarkGray
    if ($StartFrom -ne "de") {
        Write-Host "Retomando a partir de -$StartFrom." -ForegroundColor Yellow
    }

    foreach ($knob in $countermeasures) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " Iniciando benchmark -$knob ($Repeat repeticoes)" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan

        # Processo separado: um 'exit' no benchmark filho nao encerra o orquestrador.
        $childArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $PSCommandPath,
            "-Sha256", $Sha256,
            "-Countermeasure", $knob,
            "-SampleType", $SampleType,
            "-SamplesDir", $SamplesDir,
            "-SignatureFile", $SignatureFile,
            "-TimeoutSeconds", "$TimeoutSeconds",
            "-SampleObservationSeconds", "$SampleObservationSeconds",
            "-MemscanTimeoutSeconds", "$MemscanTimeoutSeconds",
            "-Configuration", $Configuration,
            "-Repeat", "$Repeat"
        )
        if (-not $FollowChild) { $childArgs += "-FollowChild:false" }
        if ($SkipMemscan) { $childArgs += "-SkipMemscan" }
        if ($Loop1000) { $childArgs += "-Loop1000" }

        $childStarted = (Get-Date).AddSeconds(-2)
        & powershell.exe @childArgs
        $childExit = $LASTEXITCODE

        $childJson = Get-ChildItem -Path $benchmarkDir `
            -Filter "benchmark-$SampleType-$knob-$allTag-*.json" -File |
            Where-Object { $_.LastWriteTime -ge $childStarted } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if (-not $childJson) {
            throw "Benchmark failed for countermeasure -$knob (exit=$childExit); relatorio JSON nao foi gerado."
        }
        if ($childExit -ne 0) {
            # Pin/kill as vezes deixa exit code residual no processo filho mesmo com relatorio OK.
            Write-Warning ("Filho -$knob terminou com exit=$childExit, mas o JSON existe; seguindo em frente.")
        }
        $allReports += Get-Content $childJson.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    $consolidatedReport = Save-ConsolidatedBenchmarkReports -Reports $allReports -Tag $allTag
    Write-Host ""
    Write-Host "Todos os benchmarks foram concluidos." -ForegroundColor Green
    Write-Host ("CSV consolidado  : {0}" -f $consolidatedReport.CsvPath) -ForegroundColor Green
    Write-Host ("JSON consolidado : {0}" -f $consolidatedReport.JsonPath) -ForegroundColor Green
    exit 0
}

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
Write-Host "  [2] Amostra real ($SampleType)             : $sample"
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

Write-Host "[2/2] Executando amostra real ($SampleType): $Repeat rodada(s), baseline e -$Countermeasure..." -ForegroundColor Yellow
$baselineRuns = @()
$countermeasureRuns = @()
$benchmarkRows = @()

for ($iteration = 1; $iteration -le $Repeat; $iteration++) {
    if ($iteration -eq 1 -or $iteration -eq $Repeat -or ($iteration % 10) -eq 0) {
        Write-Host ("    rodada {0}/{1}" -f $iteration, $Repeat) -ForegroundColor DarkGray
    }

    # Alterna qual cenario executa primeiro para reduzir vies de aquecimento e deriva temporal.
    $executionOrder = if (($iteration % 2) -eq 1) {
        @("baseline", "countermeasure")
    }
    else {
        @("countermeasure", "baseline")
    }

    for ($orderPosition = 0; $orderPosition -lt $executionOrder.Count; $orderPosition++) {
        $mode = $executionOrder[$orderPosition]
        if ($mode -eq "baseline") {
            $run = Invoke-BenchmarkSampleRun -PinExe $pinExe -ToolDll $toolDll -SamplePath $sample `
                -Knobs @() -FollowChild $FollowChild -TimeoutSeconds $TimeoutSeconds `
                -ObservationSeconds $SampleObservationSeconds `
                -Scenario "pin_baseline_$iteration" -ProgressLabel "baseline rodada $iteration/$Repeat"
            $baselineRuns += $run
        }
        else {
            $run = Invoke-BenchmarkSampleRun -PinExe $pinExe -ToolDll $toolDll -SamplePath $sample `
                -Knobs $cmKnobs -FollowChild $FollowChild -TimeoutSeconds $TimeoutSeconds `
                -ObservationSeconds $SampleObservationSeconds `
                -Scenario "pin_$($Countermeasure)_$iteration" -ProgressLabel "-$Countermeasure rodada $iteration/$Repeat"
            $countermeasureRuns += $run
        }

        $benchmarkRows += [PSCustomObject]@{
            Iteration      = $iteration
            ExecutionOrder = $orderPosition + 1
            Mode           = $mode
            Countermeasure = $Countermeasure
            SampleType     = $SampleType
            Sha256         = $Sha256
            Seconds        = (Get-JsonSafeNumber $run.Seconds)
            Outcome        = $run.Outcome
            ExitCode       = $run.ExitCode
            TimedOut       = $run.TimedOut
            ObservationCompleted = [bool]$run.ObservationCompleted
            ObservationSeconds = $run.ObservationSeconds
            ResourceMetricsAvailable = [bool]$run.ResourceMetrics.Available
            ResourceSampleCount = $run.ResourceMetrics.SampleCount
            CpuSeconds = (Get-JsonSafeNumber $run.ResourceMetrics.CpuSeconds)
            CpuPercentOneCore = (Get-JsonSafeNumber $run.ResourceMetrics.CpuPercentOneCore)
            CpuPercentTotalCapacity = (Get-JsonSafeNumber $run.ResourceMetrics.CpuPercentTotalCapacity)
            AverageWorkingSetMB = (Get-JsonSafeNumber $run.ResourceMetrics.AverageWorkingSetMB)
            PeakWorkingSetMB = (Get-JsonSafeNumber $run.ResourceMetrics.PeakWorkingSetMB)
            PeakPrivateMemoryMB = (Get-JsonSafeNumber $run.ResourceMetrics.PeakPrivateMemoryMB)
            Scenario       = $run.Scenario
        }
    }
}

$baseMalware = if ($Repeat -eq 1) {
    $baselineRuns[0]
}
else {
    New-AggregateRun -Runs $baselineRuns -Scenario "pin_baseline_aggregate"
}
$cmMalware = if ($Repeat -eq 1) {
    $countermeasureRuns[0]
}
else {
    New-AggregateRun -Runs $countermeasureRuns -Scenario "pin_$($Countermeasure)_aggregate"
}

$basePinCmd = Get-PinCommandFromRun -Run $baseMemscan -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe -Knobs $pocBaseKnobs
$cmPinCmd = Get-PinCommandFromRun -Run $cmMemscan -PinExe $pinExe -ToolDll $toolDll -SamplePath $pocExe -Knobs $pocCmKnobs

Show-BaselineReport -Knob $Countermeasure -PocRun $baseMemscan -Counts $baseCounts -MalwareRun $baseMalware -PinCommand $basePinCmd -SamplePath $sample
Show-CmReport -Knob $Countermeasure -PocRun $cmMemscan -Counts $cmCounts -MalwareRun $cmMalware -PinCommand $cmPinCmd -SamplePath $sample

# Limpeza agressiva antes de gravar: residuos do malware (follow_execv) podem
# derrubar o PowerShell no ConvertTo-Json/Export-Csv sem mensagem clara.
[void](Stop-ResidualSampleProcesses -SamplePath $sample)
Start-Sleep -Milliseconds 500

try {
    Write-RunSummaryLog -Tag $tag -Knob $Countermeasure -BaselineMalware $baseMalware -CmMalware $cmMalware `
        -BaselinePoc $baseMemscan -CmPoc $cmMemscan -BaselineCounts $baseCounts -CmCounts $cmCounts

    Save-RunArtifacts -Tag $tag -Knob $Countermeasure -BaselineMalware $baseMalware -CmMalware $cmMalware `
        -BaselineMemscan $baseMemscan -CmMemscan $cmMemscan -BaselineCounts $baseCounts -CmCounts $cmCounts

    if ($Repeat -gt 1) {
        $benchmarkReport = Save-BenchmarkReports -Knob $Countermeasure -Tag $tag `
            -BaselineRuns $baselineRuns -CountermeasureRuns $countermeasureRuns -Rows $benchmarkRows `
            -BaselinePoc $baseMemscan -CountermeasurePoc $cmMemscan `
            -BaselineCounts $baseCounts -CountermeasureCounts $cmCounts

        Write-Host ""
        Write-Host "Respostas do relatorio:" -ForegroundColor Cyan
        Write-Host ("  funcional      : {0} - {1}" -f `
            $benchmarkReport.FunctionalEvidence.Status, $benchmarkReport.FunctionalEvidence.Answer) `
            -ForegroundColor $(if ($benchmarkReport.FunctionalEvidence.Status -eq "PASS") { "Green" } else { "Yellow" })
        Write-Host ("  evidencia      : " + [string]$benchmarkReport.FunctionalEvidence.EvidenceSummary)
        Write-Host ("  desempenho     : {0} - {1}" -f `
            $benchmarkReport.PerformanceAssessment.Status, $benchmarkReport.PerformanceAssessment.Answer) `
            -ForegroundColor $(if ($benchmarkReport.PerformanceAssessment.Status -eq "VALID") { "Green" } else { "Yellow" })
        Write-Host ""
        Write-Host "Estatisticas da amostra:" -ForegroundColor Cyan
        Write-Host ("  baseline       : media={0}s | mediana={1}s | p95={2}s | validas={3}/{4} (observed={5})" -f `
            $benchmarkReport.Baseline.MeanSeconds, $benchmarkReport.Baseline.MedianSeconds, `
            $benchmarkReport.Baseline.P95Seconds, $benchmarkReport.Baseline.Valid, `
            $benchmarkReport.Baseline.Attempted, $benchmarkReport.Baseline.Observed)
        Write-Host ("  -{0}             : media={1}s | mediana={2}s | p95={3}s | validas={4}/{5} (observed={6})" -f `
            $Countermeasure, $benchmarkReport.CountermeasureResult.MeanSeconds, `
            $benchmarkReport.CountermeasureResult.MedianSeconds, $benchmarkReport.CountermeasureResult.P95Seconds, `
            $benchmarkReport.CountermeasureResult.Valid, $benchmarkReport.CountermeasureResult.Attempted, `
            $benchmarkReport.CountermeasureResult.Observed)
        Write-Host ("  pares validos  : {0}/{1}" -f `
            $benchmarkReport.PairedEffect.ValidPairs, $benchmarkReport.PairedEffect.AttemptedPairs)
        if ($benchmarkReport.ComparisonValid) {
            Write-Host ("  delta pareado  : mediana={0}s | variacao mediana={1}%" -f `
                $benchmarkReport.MedianDeltaSeconds, $benchmarkReport.MedianChangePercent)
        }
        else {
            Write-Host ("  comparacao     : INVALIDA - {0}" -f $benchmarkReport.ComparisonReason) -ForegroundColor Yellow
        }
        Write-Host ("  CSV            : {0}" -f $benchmarkReport.CsvPath) -ForegroundColor Green
        Write-Host ("  JSON           : {0}" -f $benchmarkReport.JsonPath) -ForegroundColor Green
    }
}
catch {
    $errDir = Join-Path $repoRoot "Resultados\benchmarks"
    New-Item -ItemType Directory -Force -Path $errDir | Out-Null
    $errPath = Join-Path $errDir ("error-{0}-{1}-{2}.txt" -f $SampleType, $Countermeasure, $tag)
    $errText = @()
    $errText += "Time: $(Get-Date -Format o)"
    $errText += "Countermeasure: -$Countermeasure"
    $errText += "SampleType: $SampleType"
    $errText += "Sha256: $Sha256"
    $errText += "Message: $($_.Exception.Message)"
    $errText += "Type: $($_.Exception.GetType().FullName)"
    $errText += "ScriptStackTrace:"
    $errText += $_.ScriptStackTrace
    $errText += "InvocationInfo:"
    $errText += ($_.InvocationInfo.PositionMessage)
    $errText | Set-Content -Path $errPath -Encoding UTF8
    Write-Host ""
    Write-Host ("ERRO ao salvar relatorio -$Countermeasure : {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ("Detalhes: {0}" -f $errPath) -ForegroundColor Yellow
    throw
}

# Evita que exit code residual do pin.exe (ex.: apos Kill na janela de observacao)
# vaze para o orquestrador -AllCountermeasures.
exit 0

