#Requires -Version 5.1
# Search mode: 10 s -dp -mc on corpus PEs until Toolhelp fires.
# Does NOT restore the snapshot between samples. After a HIT, copy OutDir
# to the host, restore tomware_go, and re-run that one sample with Run-M3-CaseStudy.ps1.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\m3_batch",
    [string]$GateScript = "",
    [int]$WindowSec = 10,
    [int]$MaxSamples = 50
)
$ErrorActionPreference = "Stop"
if (-not $GateScript) {
    $GateScript = Join-Path $PSScriptRoot "Run-M3-CaseStudy.ps1"
}
if (-not (Test-Path $GateScript)) { throw "Run-M3-CaseStudy.ps1 missing: $GateScript" }

$skip = @{
    "1693df9d970e011cf1c827fceaf49a3724f4478bc0ed7dc50f2d90ea417b6d38" = "MAL_08_already_rejected"
    "2a2b6b75359f4b74de136bc2c3c3a31633d3fcc169f2e2789e4d3f776ebb9e24" = "MAL_13_already_rejected"
    "022066efc497ee51fc55bfbac818f0c8c0194b4fcd6dc89815c30b6ca11d286c" = "MAL_01_already_rejected"
    "096473a4a449d224ac737fd6bb0f326c0aa7f6d713c57f6a728a1bd362671ebc" = "BEN_17_already_rejected"
}

$corpus = Join-Path $RepoRoot "experiment\corpus\corpus.csv"
if (-not (Test-Path $corpus)) { throw "corpus.csv missing: $corpus" }
$all = @(Import-Csv $corpus)

# Persistent malware first (more likely to enumerate processes at startup), then other malware.
$ordered = @($all | Where-Object { $_.group -eq "malicious" -and $_.execution_profile -eq "persistent" })
$ordered += @($all | Where-Object { $_.group -eq "malicious" -and $_.execution_profile -ne "persistent" })

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$csvPath = Join-Path $OutDir "batch_verdict.csv"
$done = @{}
$rows = New-Object System.Collections.Generic.List[object]
if (Test-Path $csvPath) {
    foreach ($p in @(Import-Csv $csvPath)) {
        $done[$p.sha256] = $true
        [void]$rows.Add($p)
    }
    Write-Host ("resume {0} rows" -f $rows.Count)
}

$n = 0
foreach ($s in $ordered) {
    if ($n -ge $MaxSamples) { break }
    $sha = ([string]$s.sha256).ToLowerInvariant()
    if ($skip.ContainsKey($sha)) { continue }
    if ($done.ContainsKey($sha)) { continue }
    $n++
    $id = [string]$s.sample_id
    Write-Host ("==== {0}/{1} {2} {3}" -f $n, $MaxSamples, $id, $s.execution_profile)
    $oneOut = Join-Path $OutDir $id
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GateScript `
        -Phase Gate -SampleId $id -Sha256 $sha -RepoRoot $RepoRoot -OutDir $oneOut -WindowSec $WindowSec
    $vfile = Join-Path $oneOut ($id + "\verdict.txt")
    $verdict = "NO_VERDICT"
    $peCalls = ""
    $peFilt = ""
    if (Test-Path $vfile) {
        foreach ($line in Get-Content $vfile) {
            if ($line -like "verdict=*") { $verdict = $line.Substring(8) }
            if ($line -like "pe_calls_intercepted=*") { $peCalls = $line.Substring(22) }
            if ($line -like "pe_processes_filtered=*") { $peFilt = $line.Substring(23) }
        }
    }
    $row = [pscustomobject]@{
        sample_id = $id
        sha256 = $sha
        profile = $s.execution_profile
        verdict = $verdict
        pe_calls_intercepted = $peCalls
        pe_processes_filtered = $peFilt
    }
    [void]$rows.Add($row)
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding ASCII
    Write-Host ("saved {0}" -f $csvPath)
    if ($verdict -eq "GATE_TOOLHELP_SEEN") {
        Write-Host "HIT. Stop the batch. Copy this OutDir to the host, restore tomware_go, re-gate this sample alone."
        break
    }
}
Write-Host "batch done"
