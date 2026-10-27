#Requires -Version 5.1
# NAT-only host check of collector v2.1 ExitCode. No malware. No Pin.
$ErrorActionPreference = "Stop"
# this file is TOMWare/experiment/revision_gap_closure/03_collector
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
. (Join-Path $repo "experiment\scripts\collectors\ProcessCollector.ps1")
$outDir = $PSScriptRoot

function Classify-Exit {
    param($ExitCode)
    $crash = $false
    $exc = $null
    $reason = "natural_exit"
    if ($null -ne $ExitCode -and ($ExitCode -lt 0 -or $ExitCode -gt 65535)) {
        $crash = $true
        $exc = ("0x{0:X8}" -f $ExitCode)
        $reason = "exception_crash"
    } elseif ($null -eq $ExitCode) {
        $reason = "exited_before_limit_exit_code_unknown"
    }
    return [PSCustomObject]@{ crash = $crash; exception_code = $exc; termination_reason = $reason }
}

function Invoke-Redirected {
    param([string]$FilePath, [string[]]$Arguments)
    $tag = [Guid]::NewGuid().ToString("N")
    $outF = Join-Path $env:TEMP "exit_out_$tag.txt"
    $errF = Join-Path $env:TEMP "exit_err_$tag.txt"
    $obs = Start-ObservedProcess -FilePath $FilePath -ArgumentList $Arguments `
        -StdoutPath $outF -StderrPath $errF
    $safe = Complete-ObservedProcess -Observed $obs -WaitMs 15000
    Remove-Item $outF, $errF -Force -ErrorAction SilentlyContinue
    $cls = Classify-Exit -ExitCode $safe
    return [PSCustomObject]@{
        name = "$FilePath $($Arguments -join ' ')"
        safe_exit_code = $safe
        crash = $cls.crash
        exception_code = $cls.exception_code
        termination_reason = $cls.termination_reason
    }
}

$nullRule = Classify-Exit -ExitCode $null
$cases = @(
    (Invoke-Redirected -FilePath "cmd.exe" -Arguments @("/c", "exit", "0")),
    (Invoke-Redirected -FilePath "cmd.exe" -Arguments @("/c", "exit", "1")),
    (Invoke-Redirected -FilePath "cmd.exe" -Arguments @("/c", "exit", "259"))
)
$cases += [PSCustomObject]@{
    name = "null_exit_must_not_be_crash"
    safe_exit_code = $null
    crash = $nullRule.crash
    exception_code = $nullRule.exception_code
    termination_reason = $nullRule.termination_reason
}

$path = Join-Path $outDir "exit_code_host_test.csv"
$cases | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
$cases | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "wrote $path"

$ok0 = ($cases[0].safe_exit_code -eq 0) -and (-not $cases[0].crash)
$ok1 = ($cases[1].safe_exit_code -eq 1) -and (-not $cases[1].crash)
$okN = ($cases[3].termination_reason -eq "exited_before_limit_exit_code_unknown") -and (-not $cases[3].crash)
if (-not ($ok0 -and $ok1 -and $okN)) {
    throw "Exit-code capture test failed: exit0=$ok0 exit1=$ok1 null=$okN codes=$($cases[0].safe_exit_code),$($cases[1].safe_exit_code)"
}
Write-Host "PASS collector v2.1 exit-code rule on host NAT"
