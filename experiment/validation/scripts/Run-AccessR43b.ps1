#Requires -Version 5.1
# Access R4.3b process-tree diagnostic. Campaign id access_r43b_process_tree.
# Preserves access_r43_skewmask_diag. Fixes automatic $pid (use $procId).
# Does NOT rerun the 9000. Does NOT change SkewMask.cpp. Does NOT install Pin 2.14.
# DLL 4BBC6270. Snapshot tomware_go. Network off. Guest only.
# Selection (a priori from corpus_aligned_10k medians): persistent benign
# TMW0 n_ok=0 and TMW_DO n_ok>=6 with ~60 s wall: BEN_28, BEN_46, BEN_47.
param(
    [ValidateSet("Prepare", "RUN")][string]$Job = "Prepare",
    [ValidateSet("Native", "TMW0", "TMW_DO")][string]$Mode = "Native",
    [ValidatePattern("^[A-Za-z0-9_]*$")][string]$SampleId = "",
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\access_r43b",
    [int]$WindowSec = 60,
    [int]$SampleMs = 200,
    [string]$ExpectedDllSha256 = "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6"
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "Run only inside the Windows analysis VM." }

$Catalog = [ordered]@{
    BEN_28 = "0111d485351ef0deffd9403a0f8e123759a04a928fbd055b901de18164c4fa39"
    BEN_46 = "0ab9f2923dac072716a8380ec909ea9f74b9f1755f149c2a41f61b49d93633a2"
    BEN_47 = "0abd30c5a4a6f17c9f1f718da42435ed05927a3c0ee5430a8ff337027f875dfd"
}

function Join-Args([string[]]$ArgumentList) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($a in @($ArgumentList)) {
        if ($null -eq $a -or $a -eq "") { continue }
        if ($a -match '[\s"]') { $parts.Add(('"{0}"' -f ($a -replace '"', '\"'))) }
        else { $parts.Add([string]$a) }
    }
    return ($parts -join " ")
}

function Stop-Leftovers {
    cmd.exe /c "taskkill /IM pin.exe /T /F >nul 2>&1" | Out-Null
    cmd.exe /c "taskkill /IM pinbin.exe /T /F >nul 2>&1" | Out-Null
    Start-Sleep -Milliseconds 400
}

function Find-HashExe([string]$Sha, [string]$Root) {
    $shaU = $Sha.ToUpperInvariant(); $shaL = $Sha.ToLowerInvariant()
    $dirs = @(
        (Join-Path $Root "samples\benign"),
        (Join-Path $Root "malwares\benign"),
        (Join-Path $Root "samples\infected"),
        (Join-Path $Root "malwares\infected")
    )
    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        foreach ($n in @("$shaL.exe", "$shaU.exe", $shaL, $shaU)) {
            $p = Join-Path $d $n
            if (Test-Path -LiteralPath $p -PathType Leaf) { return (Resolve-Path -LiteralPath $p).Path }
        }
    }
    return $null
}

function Get-TreeText([int]$RootPid) {
    $script:TreeRows = New-Object System.Collections.Generic.List[object]
    $lines = New-Object System.Collections.Generic.List[string]
    try {
        $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
        $byParent = @{}
        foreach ($p in $all) {
            $pp = [int]$p.ParentProcessId
            if (-not $byParent.ContainsKey($pp)) { $byParent[$pp] = New-Object System.Collections.Generic.List[object] }
            $byParent[$pp].Add($p)
        }
        $stack = New-Object System.Collections.Generic.Stack[object]
        $stack.Push(@{ pid = $RootPid; depth = 0 })
        $seen = @{}
        while ($stack.Count -gt 0) {
            $cur = $stack.Pop()
            $procId = [int]$cur.pid
            if ($seen.ContainsKey($procId)) { continue }
            $seen[$procId] = $true
            $proc = $all | Where-Object { [int]$_.ProcessId -eq $procId } | Select-Object -First 1
            $name = if ($proc) { $proc.Name } else { "?" }
            $ppid = if ($proc) { [int]$proc.ParentProcessId } else { -1 }
            $lines.Add(("{0}{1} pid={2} parent={3}" -f ("  " * $cur.depth), $name, $procId, $ppid))
            $script:TreeRows.Add([pscustomobject]@{
                name = $name; pid = $procId; parent_pid = $ppid; depth = [int]$cur.depth
            })
            if ($byParent.ContainsKey($procId)) {
                foreach ($ch in $byParent[$procId]) { $stack.Push(@{ pid = [int]$ch.ProcessId; depth = $cur.depth + 1 }) }
            }
        }
    } catch {
        $lines.Add(("tree_error {0}" -f $_.Exception.Message))
    }
    return ($lines -join "`r`n")
}

function Measure-Window {
    param(
        [string]$FileName,
        [string[]]$ArgumentList,
        [string]$WorkDir,
        [string]$StdoutPath,
        [string]$StderrPath,
        [string]$ResCsv,
        [int]$WindowSec,
        [int]$SampleMs
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = Join-Args $ArgumentList
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $t0 = Get-Date
    [void]$proc.Start()
    $outFs = [IO.File]::Open($StdoutPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $errFs = [IO.File]::Open($StderrPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $outCopy = $proc.StandardOutput.BaseStream.CopyToAsync($outFs)
    $errCopy = $proc.StandardError.BaseStream.CopyToAsync($errFs)
    $res = New-Object System.Collections.Generic.List[string]
    $res.Add("utc,elapsed_ms,root_alive,tree_ws,tree_ws_peak,root_ws,root_cpu_ms,n_tree")
    $deadline = $t0.AddSeconds($WindowSec)
    $peakWs = [int64]0
    $lastTree = ""
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds $SampleMs
        $elapsed = [int]((Get-Date) - $t0).TotalMilliseconds
        $alive = 0; $rootWs = 0; $rootCpu = 0; $treeWs = 0; $nTree = 0
        try {
            $pp = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($pp -and -not $pp.HasExited) {
                $alive = 1
                $rootWs = [int64]$pp.WorkingSet64
                $rootCpu = [int64]($pp.TotalProcessorTime.TotalMilliseconds)
                $treeWs += $rootWs
                $nTree++
            }
            $kids = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $proc.Id) -ErrorAction SilentlyContinue)
            foreach ($k in $kids) {
                $nTree++
                try {
                    $kp = Get-Process -Id ([int]$k.ProcessId) -ErrorAction SilentlyContinue
                    if ($kp) { $treeWs += [int64]$kp.WorkingSet64 }
                } catch {}
            }
            $lastTree = Get-TreeText -RootPid $proc.Id
            $script:LastTreeRows = $script:TreeRows
        } catch {}
        if ($treeWs -gt $peakWs) { $peakWs = $treeWs }
        $res.Add(("{0},{1},{2},{3},{4},{5},{6},{7}" -f (Get-Date).ToUniversalTime().ToString("o"), $elapsed, $alive, $treeWs, $peakWs, $rootWs, $rootCpu, $nTree))
        if ($proc.HasExited) { break }
    }
    $timedOut = -not $proc.HasExited
    if (-not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Stop-Leftovers
    }
    try { if ($outCopy) { [void]$outCopy.Wait(1500) } } catch {}
    try { if ($errCopy) { [void]$errCopy.Wait(1500) } } catch {}
    foreach ($s in @($outFs, $errFs)) { if ($s) { try { $s.Flush(); $s.Dispose() } catch {} } }
    $code = $null
    try { if ($proc.HasExited) { $code = $proc.ExitCode } } catch {}
    Set-Content -Path $ResCsv -Value $res -Encoding ASCII
    return [PSCustomObject]@{
        timed_out = $timedOut
        exit_code = $code
        elapsed_ms = [int]((Get-Date) - $t0).TotalMilliseconds
        peak_ws = $peakWs
        root_pid = $proc.Id
        tree_text = $lastTree
    }
}

function Assert-Dll([string]$Root, [string]$Expected) {
    $dll = Join-Path $Root "x64\Release\TOMWare.dll"
    if (-not (Test-Path -LiteralPath $dll)) { throw "TOMWare.dll missing: $dll" }
    $h = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash.ToUpperInvariant()
    Write-Host ("DLL SHA-256 {0}" -f $h)
    if ($h -ne $Expected.ToUpperInvariant()) { throw "DLL differs from campaign 4BBC6270. Stop." }
    return $h
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ($Job -eq "Prepare") {
    $null = Assert-Dll $RepoRoot $ExpectedDllSha256
    Write-Host "campaign access_r43b_process_tree  window=60s  N=1 per arm"
    Write-Host "rule: persistent benign, TMW0 n_ok=0, TMW_DO n_ok>=6 in corpus_aligned_10k"
    Write-Host "not a malware case study; not an Arancino bake-off; not Pin 2.14"
    $missing = 0
    foreach ($k in $Catalog.Keys) {
        $p = Find-HashExe $Catalog[$k] $RepoRoot
        if (-not $p) { Write-Host ("MISSING {0} {1}.exe" -f $k, $Catalog[$k]); $missing++; continue }
        Write-Host ("OK {0} {1}" -f $k, $p)
    }
    if ($missing -gt 0) { throw "Copy the three SHA-named PEs into samples\benign before RUN." }
    Write-Host "next: RUN Native then TMW0 then TMW_DO for BEN_28 BEN_46 BEN_47"
    Write-Host "copy C:\TOMWare\access_r43b to host; do not overwrite access_r43"
    return
}

$dllHash = Assert-Dll $RepoRoot $ExpectedDllSha256
if (-not $Catalog.Contains($SampleId)) { throw "SampleId must be BEN_28, BEN_46, or BEN_47." }
$sha = $Catalog[$SampleId]
$exe = Find-HashExe $sha $RepoRoot
if (-not $exe) { throw ("exe missing for {0} {1}" -f $SampleId, $sha) }

$pin = Join-Path $RepoRoot "pin\intel64\bin\pin.exe"
if (-not (Test-Path -LiteralPath $pin)) { $pin = Join-Path $RepoRoot "pin\pin.exe" }
$dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
$label = "{0}_{1}" -f $SampleId, $Mode
$runDir = Join-Path $OutDir $label
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$dropDir = Join-Path $runDir "drop"
New-Item -ItemType Directory -Force -Path $dropDir | Out-Null
$stdout = Join-Path $runDir "stdout.txt"
$stderr = Join-Path $runDir "stderr.txt"
$resCsv = Join-Path $runDir "resources.csv"
$treePath = Join-Path $runDir "process_tree.txt"
$metaPath = Join-Path $runDir "run_meta.json"
$verdictPath = Join-Path $runDir "verdict.txt"

Stop-Leftovers
$knobs = ""
if ($Mode -eq "Native") {
    $file = $exe
    $argList = @()
} else {
    if (-not (Test-Path -LiteralPath $pin)) { throw "pin.exe missing" }
    $file = $pin
    $knobs = if ($Mode -eq "TMW0") { "-q" } else { "-do -q" }
    $argList = @("-follow_execv", "1", "-t", $dll) + $knobs.Split(" ") + @("--", $exe)
}

Write-Host ("RUN {0}" -f $label)
Write-Host ("  {0} {1}" -f $file, (Join-Args $argList))
$run = Measure-Window -FileName $file -ArgumentList $argList -WorkDir $dropDir `
    -StdoutPath $stdout -StderrPath $stderr -ResCsv $resCsv `
    -WindowSec $WindowSec -SampleMs $SampleMs
Set-Content -Path $treePath -Value $run.tree_text -Encoding ASCII
$treeCsv = Join-Path $runDir "process_tree.csv"
$treeJson = Join-Path $runDir "process_tree.jsonl"
$rows = @($script:LastTreeRows)
if ($rows.Count -gt 0) {
    $rows | Export-Csv -Path $treeCsv -NoTypeInformation -Encoding ASCII
    $rows | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -Path $treeJson -Encoding ASCII
} else {
    Set-Content -Path $treeCsv -Value "name,pid,parent_pid,depth" -Encoding ASCII
    Set-Content -Path $treeJson -Value "" -Encoding ASCII
}

$aliveAtWindow = [bool]$run.timed_out
$progress = "INCONCLUSIVE"
if ($aliveAtWindow) { $progress = "STILL_ALIVE_AT_WINDOW" }
elseif ($null -ne $run.exit_code) { $progress = "EXITED_BEFORE_WINDOW" }

$meta = [ordered]@{
    campaign_id = "access_r43b_process_tree"
    sample_id = $SampleId
    sha256 = $sha
    mode = $Mode
    knobs = $knobs
    window_sec = $WindowSec
    dll_sha256 = $dllHash
    pe_path = $exe
    timed_out = [bool]$run.timed_out
    exit_code = $run.exit_code
    elapsed_ms = $run.elapsed_ms
    peak_ws = $run.peak_ws
    progress = $progress
    identified = $false
    not_a_claim = "alive_is_not_progress; not Arancino; not the 9000"
}
($meta | ConvertTo-Json) | Set-Content -Path $metaPath -Encoding ASCII
Set-Content -Path $verdictPath -Value @(
    "campaign=access_r43b_process_tree",
    "sample=$SampleId",
    "mode=$Mode",
    "progress=$progress",
    "timed_out=$($run.timed_out)",
    "exit_code=$($run.exit_code)",
    "elapsed_ms=$($run.elapsed_ms)",
    "peak_ws=$($run.peak_ws)",
    "identified=false"
) -Encoding ASCII
Write-Host ("progress {0} elapsed_ms={1} exit={2} peak_ws={3}" -f $progress, $run.elapsed_ms, $run.exit_code, $run.peak_ws)
Write-Host ("out {0}" -f $runDir)
Write-Host ("NEXT copy {0} to host then restore tomware_go" -f $OutDir)
Stop-Leftovers
