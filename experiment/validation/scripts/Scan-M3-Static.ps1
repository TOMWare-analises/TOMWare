#Requires -Version 5.1
# Static only. Does not execute any PE. Ranks Toolhelp IAT / pin.exe strings.
# identified stays false. A hit here is a lead for the 10 s -dp -mc gate.
param(
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\m3_static"
)
$ErrorActionPreference = "Continue"
$needles = @(
    "CreateToolhelp32Snapshot",
    "Process32First",
    "Process32Next",
    "Module32First",
    "Module32Next",
    "pin.exe",
    "PIN_",
    "pinvm",
    "pinipc"
)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$csvPath = Join-Path $OutDir "static_leads.csv"
$rows = New-Object System.Collections.Generic.List[object]

function Find-Exe([string]$Sha, [string]$Root) {
    $shaL = $Sha.ToLowerInvariant()
    foreach ($d in @(
            (Join-Path $Root "malwares\infected"),
            (Join-Path $Root "malwares\benign"),
            (Join-Path $Root "samples\infected"),
            (Join-Path $Root "samples\benign")
        )) {
        if (-not (Test-Path $d)) { continue }
        $p = Join-Path $d ($shaL + ".exe")
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-Hits([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $ascii = [Text.Encoding]::ASCII.GetString($bytes)
    $utf16 = [Text.Encoding]::Unicode.GetString($bytes)
    $map = @{}
    foreach ($n in $needles) {
        $a = ([regex]::Matches($ascii, [regex]::Escape($n))).Count
        $u = ([regex]::Matches($utf16, [regex]::Escape($n))).Count
        $map[$n] = $a + $u
    }
    return $map
}

$corpus = Join-Path $RepoRoot "experiment\corpus\corpus.csv"
if (-not (Test-Path $corpus)) { throw "corpus.csv missing: $corpus" }
$samples = @(Import-Csv $corpus)
Write-Host ("static scan {0} rows from corpus.csv (no execute)" -f $samples.Count)

foreach ($s in $samples) {
    $exe = Find-Exe $s.sha256 $RepoRoot
    $status = "missing"
    $size = 0
    $h = @{}
    foreach ($n in $needles) { $h[$n] = 0 }
    if ($exe) {
        $status = "scanned"
        $size = (Get-Item $exe).Length
        try { $h = Get-Hits $exe } catch { $status = "read_error" }
    }
    $toolhelp = [int]$h["CreateToolhelp32Snapshot"] + [int]$h["Process32First"] + [int]$h["Process32Next"]
    $mod32 = [int]$h["Module32First"] + [int]$h["Module32Next"]
    $pin = [int]$h["pin.exe"] + [int]$h["pinvm"] + [int]$h["pinipc"]
    $pinEnv = [int]$h["PIN_"]
    $rank = 0
    if ($pin -gt 0 -and $toolhelp -gt 0) { $rank = 3 }
    elseif ($pin -gt 0) { $rank = 2 }
    elseif ($toolhelp -gt 0) { $rank = 1 }
    $rows.Add([pscustomobject]@{
            sample_id = $s.sample_id
            group = $s.group
            profile = $s.execution_profile
            sha256 = $s.sha256
            status = $status
            size_bytes = $size
            rank = $rank
            pin_exe = $pin
            pin_env = $pinEnv
            toolhelp = $toolhelp
            module32 = $mod32
            CreateToolhelp32Snapshot = [int]$h["CreateToolhelp32Snapshot"]
            Process32Next = [int]$h["Process32Next"]
        })
    Write-Host ("{0} {1} rank={2} pin_exe={3} toolhelp={4} {5}" -f $s.sample_id, $status, $rank, $pin, $toolhelp, $s.group)
}

$rows | Sort-Object rank, toolhelp -Descending |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding ASCII
Write-Host ("wrote {0}" -f $csvPath)
Write-Host "rank 3 = pin.exe string AND Toolhelp (best lead). rank 1 = Toolhelp only (IAT/string, still not a case)."
Write-Host "Do not set identified=true from this CSV."
