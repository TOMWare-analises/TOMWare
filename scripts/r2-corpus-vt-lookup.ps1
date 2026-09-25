#Requires -Version 5.1
<#
.SYNOPSIS
  Lookup VirusTotal popular threat labels for TOMWare malware corpus (hash-only; no upload).

.DESCRIPTION
  Needs a free VT API key: https://www.virustotal.com/gui/my-apikey

  Key resolution order:
    1) -ApiKey parameter
    2) $env:VT_API_KEY
    3) TOMWare\.env  (or parent\.env) line VT_API_KEY=...

  Setup:
    copy .env.example .env
    # edit .env and set VT_API_KEY=...
    .\scripts\r2-corpus-vt-lookup.ps1

.EXAMPLE
  .\scripts\r2-corpus-vt-lookup.ps1
#>
[CmdletBinding()]
param(
    [string]$ApiKey = "",
    [string]$CorpusCsv = "",
    [string]$OutJson = "",
    [string]$OutCsv = "",
    [int]$SleepSeconds = 16
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Get-DotEnvValue {
    param([string]$Key, [string[]]$Paths)
    foreach ($p in $Paths) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        foreach ($line in Get-Content -LiteralPath $p) {
            $t = $line.Trim()
            if (-not $t -or $t.StartsWith("#")) { continue }
            $eq = $t.IndexOf("=")
            if ($eq -lt 1) { continue }
            $k = $t.Substring(0, $eq).Trim()
            if ($k -ne $Key) { continue }
            $v = $t.Substring($eq + 1).Trim()
            if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
                $v = $v.Substring(1, $v.Length - 2)
            }
            if ($v) { return $v }
        }
    }
    return ""
}

if (-not $ApiKey) { $ApiKey = $env:VT_API_KEY }
if (-not $ApiKey) {
    $ApiKey = Get-DotEnvValue -Key "VT_API_KEY" -Paths @(
        (Join-Path $repo ".env"),
        (Join-Path (Split-Path -Parent $repo) ".env")
    )
}

if (-not $CorpusCsv) {
    $CorpusCsv = Join-Path (Split-Path -Parent $repo) "evidencias_VM\r2_analytics\corpus_auditable_table.csv"
}
if (-not $OutJson) {
    $OutJson = Join-Path (Split-Path -Parent $repo) "evidencias_VM_R2\corpus_family_lookups_virustotal.json"
}
if (-not $OutCsv) {
    $OutCsv = Join-Path (Split-Path -Parent $repo) "evidencias_VM_R2\corpus_family_lookups_virustotal.csv"
}

if (-not $ApiKey) {
    throw "Missing VT API key. Copy .env.example to .env and set VT_API_KEY=... (or set env VT_API_KEY)."
}

$rows = @(Import-Csv -Path $CorpusCsv | Where-Object { $_.group -eq 'malware' })
$results = @()

foreach ($r in $rows) {
    $sha = $r.sha256.ToLowerInvariant()
    $sha8 = $r.sha8
    Write-Host ("VT lookup {0}..." -f $sha8) -ForegroundColor Cyan
    $uri = "https://www.virustotal.com/api/v3/files/$sha"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Headers @{ 'x-apikey' = $ApiKey } -Method Get
        $a = $resp.data.attributes
        $stats = $a.last_analysis_stats
        $pop = $a.popular_threat_classification
        $suggested = $null
        if ($pop -and $pop.suggested_threat_label) { $suggested = $pop.suggested_threat_label }
        $cats = @()
        if ($pop -and $pop.popular_threat_category) {
            $cats = @($pop.popular_threat_category | ForEach-Object { $_.value })
        }
        $names = @()
        if ($pop -and $pop.popular_threat_name) {
            $names = @($pop.popular_threat_name | ForEach-Object { $_.value })
        }
        $packers = @()
        if ($a.packers) { $packers = @($a.packers.PSObject.Properties.Name) }

        $labelText = if ($suggested) { $suggested } else { '(no suggested label)' }
        $obj = [PSCustomObject]@{
            sha8                   = $sha8
            sha256                 = $sha
            vt_found               = $true
            malicious              = $stats.malicious
            suspicious             = $stats.suspicious
            undetected             = $stats.undetected
            suggested_threat_label = $suggested
            popular_threat_names   = ($names -join ';')
            popular_threat_cats    = ($cats -join ';')
            packers                = ($packers -join ';')
            type_description       = $a.type_description
            meaningful_name        = $a.meaningful_name
            last_analysis_date     = $a.last_analysis_date
            link                   = ("https://www.virustotal.com/gui/file/{0}" -f $sha)
            error                  = ""
        }
        Write-Host ("  -> {0} (malicious={1})" -f $labelText, $stats.malicious) -ForegroundColor Green
    }
    catch {
        $code = $null
        try { $code = $_.Exception.Response.StatusCode.value__ } catch {}
        $obj = [PSCustomObject]@{
            sha8                   = $sha8
            sha256                 = $sha
            vt_found               = $false
            malicious              = ""
            suspicious             = ""
            undetected             = ""
            suggested_threat_label = ""
            popular_threat_names   = ""
            popular_threat_cats    = ""
            packers                = ""
            type_description       = ""
            meaningful_name        = ""
            last_analysis_date     = ""
            link                   = ("https://www.virustotal.com/gui/file/{0}" -f $sha)
            error                  = ("HTTP {0}: {1}" -f $code, $_.Exception.Message)
        }
        Write-Host ("  -> NOT FOUND / error: {0}" -f $obj.error) -ForegroundColor Yellow
    }
    $results += $obj
    Start-Sleep -Seconds $SleepSeconds
}

$results | ConvertTo-Json -Depth 5 | Set-Content -Path $OutJson -Encoding UTF8
$results | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Wrote {0}" -f $OutJson) -ForegroundColor Green
Write-Host ("Wrote {0}" -f $OutCsv) -ForegroundColor Green
Write-Host "Next: tell the agent the CSV is ready (do not paste the API key)." -ForegroundColor Cyan
