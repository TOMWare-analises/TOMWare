#Requires -Version 5.1
<#
.SYNOPSIS
  Reviewer 2 item 6 - behavioral fidelity (subset + optional expanded infected).

.DESCRIPTION
  Levels: native | pin_empty | pin_fidelity | tomware_disabled | tomware_do

  Default subset (revised malware due to missing package samples):
    3 benign (unchanged) +
    3 malware available as zip+prior evidence:
      17c79863... (kept from a-priori)
      66ebbc7d... (replacement for absent 0f20b0c9)
      57448277... (replacement for absent 430b487c)

  -AllInfected: also/only run every *.exe under malwares\infected (expanded N).

.EXAMPLE
  cd C:\TOMWare
  .\scripts\r2-extract-infected.ps1
  .\scripts\r2-behavioral-fidelity.ps1 -MalwareOnly
  .\scripts\r2-behavioral-fidelity.ps1 -AllInfected -SkipBenign
  .\scripts\r2-behavioral-fidelity.ps1 -AllBenign -SkipMalware
  # Resume after VM crash / file lock (keeps existing CSV rows; skips complete 5-level matrices):
  .\scripts\r2-behavioral-fidelity.ps1 -MalwareOnly -Resume -OnlySha8 66ebbc7d -TimeoutSeconds 120
  .\scripts\r2-behavioral-fidelity.ps1 -AllInfected -SkipBenign -Resume -TimeoutSeconds 120
  # Crash-resistant malware mode (abort shutdown + mirror CSV to Downloads + 1 sample then exit):
  .\scripts\r2-behavioral-fidelity.ps1 -AllInfected -SkipBenign -Resume -SafeMalware -OneSampleThenExit -TimeoutSeconds 60
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$OutDir = "",
    [int]$TimeoutSeconds = 45,
    [int]$Repeat = 1,
    [switch]$MalwareOnly,
    [switch]$SkipBenign,
    [switch]$SkipMalware,
    [switch]$AllInfected,
    [switch]$AllBenign,
    [switch]$ExtractFirst,
    [switch]$Resume,
    [string]$OnlySha8 = "",
    [switch]$SafeMalware,
    [switch]$OneSampleThenExit,
    [string]$MirrorDir = "",
    [switch]$NoShareMirror
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $RepoRoot
. (Join-Path $RepoRoot "scripts/lib/TomwareBenchmark.ps1")

$pinExe = Join-Path $RepoRoot "pin/pin.exe"
$tomware = Join-Path $RepoRoot "x64/Release/TOMWare.dll"
$empty = Join-Path $RepoRoot "x64/Release/EmptyPinTool.dll"
$fidelity = Join-Path $RepoRoot "x64/Release/FidelityProbe.dll"

if (-not (Test-Path $pinExe)) { throw "pin.exe missing" }
if (-not (Test-Path $tomware)) { throw "TOMWare.dll missing" }
if (-not (Test-Path $empty)) { throw "EmptyPinTool.dll missing - copy from host x64\Release" }
if (-not (Test-Path $fidelity)) { throw "FidelityProbe.dll missing - copy from host x64\Release" }

if ($ExtractFirst) {
    & (Join-Path $RepoRoot "scripts\r2-extract-infected.ps1") -RepoRoot $RepoRoot
}

if (-not $OutDir) {
    if ($AllInfected -and $AllBenign) {
        $tag = "behavioral_fidelity_expanded_all"
    }
    elseif ($AllInfected) {
        $tag = "behavioral_fidelity_expanded"
    }
    elseif ($AllBenign) {
        $tag = "behavioral_fidelity_benign_all"
    }
    else {
        $tag = "behavioral_fidelity"
    }
    $OutDir = Join-Path $RepoRoot ("Resultados\evidencias_VM_R2\" + $tag)
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$probeDir = Join-Path $OutDir "probe_outputs"
New-Item -ItemType Directory -Force -Path $probeDir | Out-Null

# Benign a-priori (unchanged)
$benignSubset = @(
    @{ Group = "benign";  Sha = "1128D0B41456073E0B22E328CE4A89D0877F7D18147DF6B339A4CCE758A1DAAB"; Role = "a_priori" },
    @{ Group = "benign";  Sha = "16B45C2C51D45CA4AE42B4251430113100142A5898F9B22D059F03456963BC2D"; Role = "a_priori" },
    @{ Group = "benign";  Sha = "445E672DB08239BA38527A27208DD104D2889CD29A68DC65DC0676F3252ED347"; Role = "a_priori" }
)

# Malware revised subset (document replacements)
$malwareSubset = @(
    @{ Group = "malware"; Sha = "17c7986320e427a1106f3bbed1e122bcb0d9d38611d159c120df11d9689f4ec4"; Role = "a_priori_kept" },
    @{ Group = "malware"; Sha = "66ebbc7d5f4e3c2b392af7f624ad328c8b4dc2e198f7bf585506b132607e9fbd"; Role = "replacement_for_0f20b0c9" },
    @{ Group = "malware"; Sha = "574482778792874721df6f4461490efbc7bbc6dfb833184f20e77ecd61e68270"; Role = "replacement_for_430b487c" }
)

$subset = @()
$wantBenignSubset = (-not $MalwareOnly -and -not $SkipBenign -and -not $AllBenign)
$wantMalwareSubset = (-not $SkipMalware -and -not $AllInfected -and ($MalwareOnly -or (-not $AllBenign)))

# Default full revised subset (3+3) when no expansion switches
if (-not $AllInfected -and -not $AllBenign -and -not $MalwareOnly) {
    $subset += $benignSubset
    $subset += $malwareSubset
}
elseif ($MalwareOnly) {
    $subset += $malwareSubset
}
elseif ($wantBenignSubset) {
    $subset += $benignSubset
}
elseif ($wantMalwareSubset -and -not $AllBenign) {
    $subset += $malwareSubset
}

if ($AllBenign) {
    $benDir = Join-Path $RepoRoot "samples\benign"
    if (-not (Test-Path $benDir)) { throw "Missing $benDir" }
    $bexes = Get-ChildItem $benDir -Filter "*.exe" -File
    foreach ($e in $bexes) {
        $sha = [IO.Path]::GetFileNameWithoutExtension($e.Name)
        $subset += @{ Group = "benign"; Sha = $sha; Role = "expanded_all_benign"; ExePath = $e.FullName }
    }
}

if ($AllInfected) {
    $infDir = Join-Path $RepoRoot "malwares\infected"
    if (-not (Test-Path $infDir)) { throw "Missing $infDir - run r2-extract-infected.ps1 first" }
    $exes = Get-ChildItem $infDir -Filter "*.exe" -File
    foreach ($e in $exes) {
        $sha = [IO.Path]::GetFileNameWithoutExtension($e.Name)
        if ($sha.Length -lt 16) { $sha = $e.BaseName }
        $subset += @{ Group = "malware"; Sha = $sha; Role = "expanded_all_infected"; ExePath = $e.FullName }
    }
}

# Dedup by Sha (prefer explicit ExePath entries)
$seen = @{}
$dedup = @()
foreach ($s in $subset) {
    $key = ($s.Sha).ToLowerInvariant()
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $dedup += $s
}
$subset = $dedup

function Resolve-SubsetExe([string]$Group, [string]$Sha, [string]$ExePath = "") {
    if ($ExePath -and (Test-Path $ExePath)) { return (Resolve-Path $ExePath).Path }
    $subs = if ($Group -eq "benign") { @("benign") } else { @("infected", "malign", "malware") }
    $roots = @(
        (Join-Path $RepoRoot "malwares"),
        (Join-Path $RepoRoot "samples")
    )
    foreach ($root in $roots) {
        foreach ($sub in $subs) {
            foreach ($c in @(
                (Join-Path $root "$sub\$Sha.exe"),
                (Join-Path $root "$sub\$Sha"),
                (Join-Path $root "$sub\$($Sha.ToLower()).exe"),
                (Join-Path $root "$sub\$($Sha.ToUpper()).exe")
            )) {
                if (Test-Path $c) { return (Resolve-Path $c).Path }
            }
            # any exe starting with sha8
            $dir = Join-Path $root $sub
            if (Test-Path $dir) {
                $hit = Get-ChildItem $dir -Filter ($Sha.Substring(0, [Math]::Min(8, $Sha.Length)) + "*.exe") -File -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($hit) { return $hit.FullName }
            }
        }
    }
    return $null
}

function Parse-FidelityOut([string]$Path) {
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    foreach ($line in Get-Content $Path -ErrorAction SilentlyContinue) {
        $parts = $line -split "\s+", 2
        if ($parts.Count -ge 2) { $map[$parts[0]] = $parts[1] }
    }
    return $map
}

$requiredLevels = @("native", "pin_empty", "pin_fidelity", "tomware_disabled", "tomware_do")
$results = @()
$csv = Join-Path $OutDir "fidelity_results.csv"

function Get-CompleteSha8Set {
    param([object[]]$Rows)
    $by = @{}
    foreach ($row in $Rows) {
        $k = ([string]$row.Sha8).ToLowerInvariant()
        if (-not $by.ContainsKey($k)) { $by[$k] = New-Object System.Collections.Generic.HashSet[string] }
        [void]$by[$k].Add([string]$row.Level)
    }
    $done = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $by.Keys) {
        $ok = $true
        foreach ($lv in $requiredLevels) {
            if (-not $by[$k].Contains($lv)) { $ok = $false; break }
        }
        if ($ok) { [void]$done.Add($k) }
    }
    return $done
}

if ($Resume -and (Test-Path $csv)) {
    $prior = @(Import-Csv -Path $csv)
    $results = @($prior)
    $doneSet = Get-CompleteSha8Set -Rows $prior
    Write-Host ("Resume: loaded {0} CSV rows; {1} SHA8 already complete (5/5)" -f $prior.Count, $doneSet.Count) -ForegroundColor Yellow
}
else {
    $doneSet = New-Object System.Collections.Generic.HashSet[string]
}

if ($OnlySha8) {
    $only = $OnlySha8.ToLowerInvariant()
    $subset = @($subset | Where-Object {
        $s8 = if ($_.Sha.Length -ge 8) { $_.Sha.Substring(0, 8) } else { $_.Sha }
        $s8.ToLowerInvariant() -eq $only
    })
    if ($subset.Count -eq 0) {
        throw "OnlySha8=$OnlySha8 matched 0 samples in current mode"
    }
    Write-Host ("OnlySha8 filter: {0} sample(s)" -f $subset.Count) -ForegroundColor Yellow
}

$protocol = @"
# Behavioral fidelity protocol (R2-6)

Mode: $(if ($AllInfected -and $AllBenign) { 'expanded_benign+infected' } elseif ($AllInfected) { 'expanded_all_infected' } elseif ($AllBenign) { 'expanded_all_benign' } elseif ($MalwareOnly) { 'malware_revised_subset' } else { 'full_revised_subset' })
Repeat=$Repeat TimeoutSeconds=$TimeoutSeconds

Conditions per sample:
1. native
2. pin_empty (EmptyPinTool.dll)
3. pin_fidelity (FidelityProbe.dll -o)  -> BBL + API watchlist
4. tomware_disabled (-q)
5. tomware_do (-do -q)

Malware subset note:
- Kept a-priori: 17c79863...
- Replaced absent 0f20b0c9 / 430b487c with 66ebbc7d... / 57448277...
  (present as zip in samples/infected AND prior evidencias_VM/malign)

Expanded:
-AllBenign: all EXEs under samples/benign (typically 17)
-AllInfected: all EXEs under malwares/infected after extract

Date: $(Get-Date -Format o)
Host: $env:COMPUTERNAME
Samples planned: $($subset.Count)
"@
$protocol | Set-Content -Path (Join-Path $OutDir "PROTOCOL.md") -Encoding UTF8
$manifestPath = Join-Path $OutDir "subset_manifest.csv"
if (-not ($Resume -and (Test-Path $manifestPath) -and $OnlySha8)) {
    $subset | ForEach-Object {
        [PSCustomObject]@{ Group = $_.Group; Sha = $_.Sha; Role = $_.Role }
    } | Export-Csv -Path $manifestPath -NoTypeInformation -Encoding UTF8
}

Write-Host ("Fidelity campaign: {0} samples -> {1}" -f $subset.Count, $OutDir) -ForegroundColor Cyan

# Defaults for malware campaigns: abort guest shutdown; optional CSV mirror
$runningMalware = ($MalwareOnly -or $AllInfected -or (-not $SkipMalware -and -not $AllBenign))
if ($NoShareMirror) {
    $MirrorDir = ""
    Write-Host "NoShareMirror: CSV only on guest disk (copy out AFTER sample, then revert snapshot)" -ForegroundColor Yellow
}
elseif ($SafeMalware -or $runningMalware) {
    if (-not $MirrorDir) {
        $tag = Split-Path -Leaf $OutDir
        $candidates = @(
            "\\vmware-host\Shared Folders\tomware_r2\$tag",
            "Z:\tomware_r2\$tag",
            "Z:\$tag",
            (Join-Path $env:USERPROFILE ("Downloads\" + $tag))
        )
        $MirrorDir = $candidates | Where-Object {
            $parent = Split-Path -Parent $_
            Test-Path $parent
        } | Select-Object -First 1
        if (-not $MirrorDir) { $MirrorDir = $candidates[-1] }
    }
    New-Item -ItemType Directory -Force -Path $MirrorDir | Out-Null
    Write-Host ("SafeMalware: shutdown-abort ON; mirror CSV -> {0}" -f $MirrorDir) -ForegroundColor Yellow
}
$watchdog = $null
if ($SafeMalware -or $runningMalware) {
    $watchdog = Start-TomwareShutdownAbortWatchdog
    Write-Host ("Shutdown-abort watchdog pid={0}" -f $watchdog.Pid) -ForegroundColor Yellow
}

function Save-FidelityCheckpoint {
    param([object[]]$Rows, [string]$CsvPath, [string]$Mirror)
    $Rows | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    if ($Mirror) {
        try {
            New-Item -ItemType Directory -Force -Path $Mirror | Out-Null
            Copy-Item -LiteralPath $CsvPath -Destination (Join-Path $Mirror "fidelity_results.csv") -Force
            $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
            Copy-Item -LiteralPath $CsvPath -Destination (Join-Path $Mirror ("fidelity_results_{0}.csv" -f $stamp)) -Force
        } catch {
            Write-Host ("  mirror WARN: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
        }
    }
}

$samplesFinishedThisRun = 0
try {
foreach ($s in $subset) {
    $exePathHint = ""
    if ($s.ContainsKey("ExePath")) { $exePathHint = [string]$s.ExePath }
    $exe = Resolve-SubsetExe -Group $s.Group -Sha $s.Sha -ExePath $exePathHint
    $sha8 = if ($s.Sha.Length -ge 8) { $s.Sha.Substring(0, 8) } else { $s.Sha }
    $sha8Key = $sha8.ToLowerInvariant()
    if ($Resume -and $doneSet.Contains($sha8Key)) {
        Write-Host ("SKIP complete {0} (already 5/5 in CSV)" -f $sha8) -ForegroundColor DarkGreen
        continue
    }
    if ($Resume) {
        # Drop partial/error rows for this SHA so a clean 5-level matrix is rewritten
        $results = @($results | Where-Object { ([string]$_.Sha8).ToLowerInvariant() -ne $sha8Key })
    }
    if (-not $exe) {
        Write-Host "MISSING sample $($s.Group) $sha8" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            Group = $s.Group; Sha8 = $sha8; Sha256 = $s.Sha; Role = $s.Role; Level = "resolve"
            Rep = 0; Outcome = "missing_exe"; Seconds = 0; ExitCode = -1
            PeakWorkingSetMB = $null; PeakTrackedProcesses = $null
            BblCount = ""; ImgCount = ""; ApiHitsTotal = ""; ProbeFile = ""
            Note = "sample exe not found - run r2-extract-infected.ps1"
        }
        continue
    }

    for ($r = 1; $r -le $Repeat; $r++) {
        Write-Host ("=== {0} {1} ({2}) rep {3}/{4} ===" -f $s.Group, $sha8, $s.Role, $r, $Repeat) -ForegroundColor Cyan
        try {
            Write-Host "  native..." -ForegroundColor DarkGray
            $nat = Invoke-TomwareNativeRun -SamplePath $exe -TimeoutSeconds $TimeoutSeconds -Scenario "fid_native_${sha8}_$r"
            $results += [PSCustomObject]@{
                Group = $s.Group; Sha8 = $sha8; Sha256 = $s.Sha; Role = $s.Role; Level = "native"; Rep = $r
                Outcome = $nat.Outcome; Seconds = $nat.Seconds; ExitCode = $nat.ExitCode
                PeakWorkingSetMB = $null; PeakTrackedProcesses = $null
                BblCount = ""; ImgCount = ""; ApiHitsTotal = ""; ProbeFile = ""
                Note = "no Pin"
            }
            Write-Host ("  native -> {0} ({1}s)" -f $nat.Outcome, $nat.Seconds) -ForegroundColor DarkGray

            Write-Host "  pin_empty..." -ForegroundColor DarkGray
            $pe = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $empty -SamplePath $exe -Knobs @() `
                -TimeoutSeconds $TimeoutSeconds -Scenario "fid_empty_${sha8}_$r" -ProgressLabel "empty-$sha8"
            $results += [PSCustomObject]@{
                Group = $s.Group; Sha8 = $sha8; Sha256 = $s.Sha; Role = $s.Role; Level = "pin_empty"; Rep = $r
                Outcome = $pe.Outcome; Seconds = $pe.Seconds; ExitCode = $pe.ExitCode
                PeakWorkingSetMB = $pe.ResourceMetrics.PeakWorkingSetMB
                PeakTrackedProcesses = $pe.ResourceMetrics.TrackedProcessPeak
                BblCount = ""; ImgCount = ""; ApiHitsTotal = ""; ProbeFile = ""
                Note = "EmptyPinTool"
            }

            Write-Host "  pin_fidelity..." -ForegroundColor DarkGray
            # Unique probe path avoids "file in use" when a prior Pin child still holds the handle
            $probeFile = Join-Path $probeDir ("{0}_{1}_rep{2}_{3}.out" -f $s.Group, $sha8, $r, (Get-Date -Format "yyyyMMddHHmmss"))
            Get-Process -Name "pin","pin.exe" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            $pf = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $fidelity -SamplePath $exe `
                -Knobs @("-o", $probeFile) -TimeoutSeconds $TimeoutSeconds `
                -Scenario "fid_probe_${sha8}_$r" -ProgressLabel "probe-$sha8"
            $fmap = Parse-FidelityOut $probeFile
            $apiTotal = 0
            foreach ($k in $fmap.Keys) {
                if ($k -like "api_*") {
                    $n = 0; [void][int]::TryParse([string]$fmap[$k], [ref]$n); $apiTotal += $n
                }
            }
            $results += [PSCustomObject]@{
                Group = $s.Group; Sha8 = $sha8; Sha256 = $s.Sha; Role = $s.Role; Level = "pin_fidelity"; Rep = $r
                Outcome = $pf.Outcome; Seconds = $pf.Seconds; ExitCode = $pf.ExitCode
                PeakWorkingSetMB = $pf.ResourceMetrics.PeakWorkingSetMB
                PeakTrackedProcesses = $pf.ResourceMetrics.TrackedProcessPeak
                BblCount = $fmap["bbl_count"]; ImgCount = $fmap["img_count"]; ApiHitsTotal = $apiTotal
                ProbeFile = [IO.Path]::GetFileName($probeFile)
                Note = "FidelityProbe BBL+API watchlist"
            }

            Write-Host "  tomware_disabled..." -ForegroundColor DarkGray
            $td = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $tomware -SamplePath $exe -Knobs @("-q") `
                -TimeoutSeconds $TimeoutSeconds -Scenario "fid_dis_${sha8}_$r" -ProgressLabel "dis-$sha8"
            $results += [PSCustomObject]@{
                Group = $s.Group; Sha8 = $sha8; Sha256 = $s.Sha; Role = $s.Role; Level = "tomware_disabled"; Rep = $r
                Outcome = $td.Outcome; Seconds = $td.Seconds; ExitCode = $td.ExitCode
                PeakWorkingSetMB = $td.ResourceMetrics.PeakWorkingSetMB
                PeakTrackedProcesses = $td.ResourceMetrics.TrackedProcessPeak
                BblCount = ""; ImgCount = ""; ApiHitsTotal = ""; ProbeFile = ""
                Note = "TOMWare modules off"
            }

            Write-Host "  tomware_do..." -ForegroundColor DarkGray
            $te = Invoke-TomwarePinRun -PinExe $pinExe -ToolDll $tomware -SamplePath $exe -Knobs @("-do", "-q") `
                -TimeoutSeconds $TimeoutSeconds -Scenario "fid_do_${sha8}_$r" -ProgressLabel "do-$sha8"
            $results += [PSCustomObject]@{
                Group = $s.Group; Sha8 = $sha8; Sha256 = $s.Sha; Role = $s.Role; Level = "tomware_do"; Rep = $r
                Outcome = $te.Outcome; Seconds = $te.Seconds; ExitCode = $te.ExitCode
                PeakWorkingSetMB = $te.ResourceMetrics.PeakWorkingSetMB
                PeakTrackedProcesses = $te.ResourceMetrics.TrackedProcessPeak
                BblCount = ""; ImgCount = ""; ApiHitsTotal = ""; ProbeFile = ""
                Note = "TOMWare -do (SkewMask)"
            }
            Save-FidelityCheckpoint -Rows $results -CsvPath $csv -Mirror $MirrorDir
            Write-Host ("  checkpoint CSV ({0} rows)" -f $results.Count) -ForegroundColor DarkGray
            # Hard cleanup: kill leftovers that could still call ExitWindows
            try { Stop-TomwareProcessTree -ProcessId 0 -SamplePath $exe } catch {}
            try { & shutdown.exe /a 2>$null | Out-Null } catch {}
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host ("  ERROR on {0}: {1}" -f $sha8, $_.Exception.Message) -ForegroundColor Red
            $results += [PSCustomObject]@{
                Group = $s.Group; Sha8 = $sha8; Sha256 = $s.Sha; Role = $s.Role; Level = "error"; Rep = $r
                Outcome = "script_error"; Seconds = 0; ExitCode = -1
                PeakWorkingSetMB = $null; PeakTrackedProcesses = $null
                BblCount = ""; ImgCount = ""; ApiHitsTotal = ""; ProbeFile = ""
                Note = $_.Exception.Message
            }
            Save-FidelityCheckpoint -Rows $results -CsvPath $csv -Mirror $MirrorDir
            try { Stop-TomwareProcessTree -ProcessId 0 -SamplePath $exe } catch {}
        }
    }
    $samplesFinishedThisRun++
    if ($OneSampleThenExit -and $samplesFinishedThisRun -ge 1) {
        Write-Host ("OneSampleThenExit: finished {0}; re-run with -Resume for next SHA" -f $sha8) -ForegroundColor Cyan
        break
    }
}
}
finally {
    if ($watchdog) { Stop-TomwareShutdownAbortWatchdog -Handle $watchdog }
    try { & shutdown.exe /a 2>$null | Out-Null } catch {}
}

Save-FidelityCheckpoint -Rows $results -CsvPath $csv -Mirror $MirrorDir
Write-Host "Wrote $csv ($($results.Count) rows)" -ForegroundColor Green
if ($MirrorDir) {
    Write-Host "Mirrored to: $MirrorDir (survives guest crash if shared/Downloads synced)" -ForegroundColor Green
}
Write-Host "Probe outputs: $probeDir" -ForegroundColor Green
Write-Host "Copy folder back to host: $OutDir" -ForegroundColor Green
if ($OneSampleThenExit) {
    Write-Host "Next: same command with -Resume (or reboot snapshot then Resume)." -ForegroundColor Yellow
}
