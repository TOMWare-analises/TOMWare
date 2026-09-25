#Requires -Version 5.1
<#
.SYNOPSIS
  Guest: roda EXATAMENTE 1 amostra de fidelidade malware, sem shared folder.

.DESCRIPTION
  -Nao monta/espelha share. CSV fica so em C:\TOMWare\Resultados\...
  Apos terminar, escreve READY_FOR_HOST.txt e encerra.
  Host deve: copiar CSV -> reverter snapshot -> devolver CSV -> proximo.

.EXAMPLE
  cd C:\TOMWare
  .\scripts\r2-fidelity-one-sample-noshares.ps1 -Mode Subset66
  .\scripts\r2-fidelity-one-sample-noshares.ps1 -Mode Expanded
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

try { & shutdown.exe /a 2>$null | Out-Null } catch {}

$tag = if ($Mode -eq "Subset66") { "behavioral_fidelity" } else { "behavioral_fidelity_expanded" }
$outDir = Join-Path $RepoRoot ("Resultados\evidencias_VM_R2\" + $tag)
$csv = Join-Path $outDir "fidelity_results.csv"
$ready = Join-Path $outDir "READY_FOR_HOST.txt"

Write-Host @"

=== ZERO-SHARE: 1 amostra ===
Mode=$Mode
OutDir=$outDir
1) Shared Folders da VMware devem estar DISABLED agora
2) Rede OFF
3) Snapshot base: pre-r2-fidelity-safe (restaurar ENTRE amostras, no host)

"@ -ForegroundColor Cyan

$common = @{
    RepoRoot          = $RepoRoot
    OutDir            = $outDir
    Resume            = $true
    SafeMalware       = $true
    NoShareMirror     = $true
    OneSampleThenExit = $true
    TimeoutSeconds    = $TimeoutSeconds
}

if ($Mode -eq "Subset66") {
    & (Join-Path $RepoRoot "scripts\r2-behavioral-fidelity.ps1") @common -MalwareOnly -OnlySha8 "66ebbc7d"
}
else {
    & (Join-Path $RepoRoot "scripts\r2-behavioral-fidelity.ps1") @common -AllInfected -SkipBenign
}

# Status for host operator
$rows = 0
$complete = 0
if (Test-Path $csv) {
    $data = @(Import-Csv $csv)
    $rows = $data.Count
    $by = @{}
    foreach ($r in $data) {
        $k = ([string]$r.Sha8).ToLowerInvariant()
        if (-not $by.ContainsKey($k)) { $by[$k] = New-Object 'System.Collections.Generic.HashSet[string]' }
        [void]$by[$k].Add([string]$r.Level)
    }
    $need = @("native", "pin_empty", "pin_fidelity", "tomware_disabled", "tomware_do")
    foreach ($k in $by.Keys) {
        $ok = $true
        foreach ($lv in $need) { if (-not $by[$k].Contains($lv)) { $ok = $false; break } }
        if ($ok) { $complete++ }
    }
}

$msg = @"
READY_FOR_HOST
Time=$(Get-Date -Format o)
Mode=$Mode
Csv=$csv
Rows=$rows
CompleteSha8=$complete
Action=COPY_THIS_CSV_TO_HOST_THEN_REVERT_SNAPSHOT
"@
Set-Content -Path $ready -Value $msg -Encoding ASCII
Write-Host $msg -ForegroundColor Green
Write-Host @"

PROXIMO (no HOST, Shared Folder OFF durante o run):
  1) Arraste SO o arquivo fidelity_results.csv para o host
     (pasta: D:\MMB\workspace\tomware-melhorias\evidencias_VM_R2\$tag\)
  2) VMware -> Snapshot -> Restore 'pre-r2-fidelity-safe'
  3) Copie o CSV de volta para o mesmo caminho na VM
  4) Rode de novo este script

"@ -ForegroundColor Yellow
