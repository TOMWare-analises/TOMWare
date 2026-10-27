#Requires -Version 5.1
# Synthetic smoke for Collect-CaseResources.ps1 -- NOT a case study, NOT T1.
# Parent exits; child stays alive; one file appears in WatchDir; window = 10 s.
param(
    [string]$OutDir = ""
)
$ErrorActionPreference = "Stop"
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot "collector_smoke" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$watch = Join-Path $OutDir "watch"
New-Item -ItemType Directory -Force -Path $watch | Out-Null
$marker = Join-Path $watch "created.txt"
if (Test-Path $marker) { Remove-Item $marker -Force }

$childCmd = "ping -n 12 127.0.0.1"
$parentCmd = @"
`$c = Start-Process -FilePath ping -ArgumentList '-n','12','127.0.0.1' -WindowStyle Hidden -PassThru
Set-Content -Path '$marker' -Value ('child_pid=' + `$c.Id) -Encoding ASCII
Start-Sleep -Seconds 2
exit 0
"@
$parent = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-Command", $parentCmd) -PassThru -WindowStyle Hidden
$collector = Join-Path $PSScriptRoot "Collect-CaseResources.ps1"
$csv = Join-Path $OutDir "resources.csv"
& $collector -PidTarget $parent.Id -OutCsv $csv -WatchDir $watch -WindowSec 10
$note = @"
Collect-CaseResources smoke -- NOT a case study. NOT T1 DONE.
WindowSec=10 (JCVHT Table 9). Parent exits; collector keeps the ping child.
PID/PPID/image/CPU/WS/peak + milestones alive/parent_exited/file_created.
Do not cite this folder as a malware case.
"@
Set-Content -Path (Join-Path $OutDir "COLETOR_FUMO.txt") -Value $note -Encoding ASCII
Write-Host "collector smoke wrote $OutDir"
