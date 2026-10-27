#Requires -Version 5.1
# T1 helper -- NOT a case study by itself.
# 10 s window matches JCVHT Table 9. Follows named children after the parent exits.
# Do not mark Major 3 DONE from this file.
param(
    [Parameter(Mandatory = $true)][int]$PidTarget,
    [string]$OutCsv = "resources.csv",
    [string]$WatchDir = "",
    [int]$WindowSec = 10,
    [int]$IntervalMs = 250
)
$ErrorActionPreference = "Continue"
$deadline = (Get-Date).AddSeconds($WindowSec)
$known = New-Object "System.Collections.Generic.HashSet[int]"
[void]$known.Add($PidTarget)
$seenFiles = New-Object "System.Collections.Generic.HashSet[string]"
if ($WatchDir -and (Test-Path $WatchDir)) {
    Get-ChildItem $WatchDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { [void]$seenFiles.Add($_.FullName) }
}
$rows = New-Object System.Collections.Generic.List[object]
function Get-Image([int]$id) {
    $p = Get-Process -Id $id -ErrorAction SilentlyContinue
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        alive = [bool]$p
        pid = $id
        ppid = $(if ($cim) { $cim.ParentProcessId } else { $null })
        name = $(if ($p) { $p.ProcessName } elseif ($cim) { $cim.Name } else { "" })
        path = $(if ($cim) { $cim.ExecutablePath } else { "" })
        ws = $(if ($p) { $p.WorkingSet64 } else { $null })
        peak_ws = $(if ($p) { $p.PeakWorkingSet64 } else { $null })
        cpu_s = $(if ($p) { $p.CPU } else { $null })
    }
}
while ((Get-Date) -lt $deadline) {
    $snapshot = @($known)
    foreach ($id in $snapshot) {
        try {
            Get-CimInstance Win32_Process -Filter "ParentProcessId=$id" -ErrorAction SilentlyContinue |
                ForEach-Object { [void]$known.Add([int]$_.ProcessId) }
        } catch {}
    }
    $newFiles = @()
    if ($WatchDir -and (Test-Path $WatchDir)) {
        Get-ChildItem $WatchDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            if ($seenFiles.Add($_.FullName)) { $newFiles += $_.Name }
        }
    }
    foreach ($id in @($known)) {
        $img = Get-Image $id
        $miles = @()
        if ($id -eq $PidTarget -and -not $img.alive) { $miles += "parent_exited" }
        if ($img.alive) { $miles += "alive" }
        if ($newFiles.Count -gt 0) { $miles += ("file_created:" + ($newFiles -join ",")) }
        $rows.Add([PSCustomObject]@{
            utc = (Get-Date).ToUniversalTime().ToString("o")
            window_s = $WindowSec
            pid = $img.pid
            ppid = $img.ppid
            image_name = $img.name
            image_path = $img.path
            cpu_s = $img.cpu_s
            working_set_bytes = $img.ws
            peak_working_set_bytes = $img.peak_ws
            alive = $img.alive
            is_root = ($id -eq $PidTarget)
            milestone = ($miles -join ";")
        })
    }
    Start-Sleep -Milliseconds $IntervalMs
}
$rows | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Host "wrote $OutCsv n=$($rows.Count) window_s=$WindowSec tracked=$($known.Count)"
Write-Host "Table 9 window is 10 s. child rows keep PID/PPID/image after parent exit."
Write-Host "This collector is not a case study."
