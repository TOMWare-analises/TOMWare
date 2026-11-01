#Requires -Version 5.1
# Access R4.3c process-tree diagnostic. Campaign id access_r43c_process_tree.
# script_rev=r43c.1
# Preserves access_r43 and access_r43b. Does NOT rerun the 9000.
# Uniform elevation (Administrator) so BEN_47 can launch (Win32 740 on r43b).
# First sample is immediate; default SampleMs=50.
# N=3 per cell. All attempts kept. Persistence is not progress.
param(
    [ValidateSet("Prepare", "RUN", "RUNMODE")][string]$Job = "Prepare",
    [ValidateSet("Native", "TMW0", "TMW_DO")][string]$Mode = "Native",
    [ValidatePattern("^[A-Za-z0-9_]*$")][string]$SampleId = "",
    [ValidateRange(1, 9)][int]$Rep = 1,
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\access_r43c",
    [int]$WindowSec = 60,
    [int]$SampleMs = 50,
    [int]$Reps = 3,
    [string]$ExpectedDllSha256 = "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6",
    [string]$ExpectedPinSha256 = "920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819"
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "Run only inside the Windows analysis VM." }

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Elevated)) {
    throw "R43c requires an elevated PowerShell (Run as administrator). Uniform elevation is the BEN_47 correction."
}

$Catalog = [ordered]@{
    BEN_28 = "0111d485351ef0deffd9403a0f8e123759a04a928fbd055b901de18164c4fa39"
    BEN_46 = "0ab9f2923dac072716a8380ec909ea9f74b9f1755f149c2a41f61b49d93633a2"
    BEN_47 = "0abd30c5a4a6f17c9f1f718da42435ed05927a3c0ee5430a8ff337027f875dfd"
}

function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
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

function Get-TreeSnapshot([int]$RootPid) {
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
            $created = ""
            if ($proc -and $proc.CreationDate) {
                try { $created = ([DateTime]$proc.CreationDate).ToUniversalTime().ToString("o") } catch { $created = "" }
            }
            $lines.Add(("{0}{1} pid={2} parent={3} created={4}" -f ("  " * $cur.depth), $name, $procId, $ppid, $created))
            $script:TreeRows.Add([pscustomobject]@{
                name = $name; pid = $procId; parent_pid = $ppid; depth = [int]$cur.depth; creation_utc = $created
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
        [string]$EventsPath,
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
    $firstSampleMs = [int]((Get-Date) - $t0).TotalMilliseconds
    $outFs = [IO.File]::Open($StdoutPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $errFs = [IO.File]::Open($StderrPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $outCopy = $proc.StandardOutput.BaseStream.CopyToAsync($outFs)
    $errCopy = $proc.StandardError.BaseStream.CopyToAsync($errFs)
    $res = New-Object System.Collections.Generic.List[string]
    $res.Add("utc,elapsed_ms,root_alive,tree_ws,tree_ws_peak,root_ws,root_cpu_ms,n_tree,n_named")
    $ev = New-Object System.Collections.Generic.List[string]
    $lifetime = @{}
    $deadline = $t0.AddSeconds($WindowSec)
    $peakWs = [int64]0
    $lastTree = ""
    $script:LastTreeRows = New-Object System.Collections.ArrayList
    $first = $true
    while ((Get-Date) -lt $deadline) {
        if (-not $first) { Start-Sleep -Milliseconds $SampleMs }
        $first = $false
        $now = Get-Date
        $elapsed = [int]($now - $t0).TotalMilliseconds
        $alive = 0; $rootWs = 0; $rootCpu = 0; $treeWs = 0; $nTree = 0; $nNamed = 0
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
            $lastTree = Get-TreeSnapshot -RootPid $proc.Id
            $script:LastTreeRows = New-Object System.Collections.ArrayList
            if ($null -ne $script:TreeRows) {
                foreach ($row in $script:TreeRows) {
                    [void]$script:LastTreeRows.Add($row)
                    if ($row.name -and $row.name -ne "?") { $nNamed++ }
                    $key = [string]$row.pid
                    if (-not $lifetime.ContainsKey($key)) {
                        $lifetime[$key] = [pscustomobject]@{
                            name = $row.name; pid = $row.pid; parent_pid = $row.parent_pid
                            depth = $row.depth; creation_utc = $row.creation_utc
                            first_seen_ms = $elapsed; last_seen_ms = $elapsed
                        }
                    } else {
                        $lifetime[$key].last_seen_ms = $elapsed
                        if ($row.name -and $row.name -ne "?") { $lifetime[$key].name = $row.name }
                        if ($row.creation_utc) { $lifetime[$key].creation_utc = $row.creation_utc }
                    }
                    $ev.Add(('{{"utc":"{0}","elapsed_ms":{1},"name":"{2}","pid":{3},"parent_pid":{4},"depth":{5},"creation_utc":"{6}","state":"alive"}}' -f `
                        $now.ToUniversalTime().ToString("o"), $elapsed, ($row.name -replace '"',''), $row.pid, $row.parent_pid, $row.depth, $row.creation_utc))
                }
            }
        } catch {}
        if ($treeWs -gt $peakWs) { $peakWs = $treeWs }
        $res.Add(("{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f $now.ToUniversalTime().ToString("o"), $elapsed, $alive, $treeWs, $peakWs, $rootWs, $rootCpu, $nTree, $nNamed))
        if ($proc.HasExited) { break }
    }
    $ended = Get-Date
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
    Set-Content -Path $EventsPath -Value $ev.ToArray() -Encoding ASCII
    $lifeLines = New-Object System.Collections.Generic.List[string]
    $lifeLines.Add("name,pid,parent_pid,depth,creation_utc,first_seen_ms,last_seen_ms,approx_exit_utc")
    foreach ($k in $lifetime.Keys) {
        $x = $lifetime[$k]
        $exitUtc = ""
        if (-not $timedOut) {
            $exitUtc = $ended.ToUniversalTime().ToString("o")
        }
        $lifeLines.Add(("{0},{1},{2},{3},{4},{5},{6},{7}" -f $x.name, $x.pid, $x.parent_pid, $x.depth, $x.creation_utc, $x.first_seen_ms, $x.last_seen_ms, $exitUtc))
    }
    return [PSCustomObject]@{
        timed_out = $timedOut
        exit_code = $code
        elapsed_ms = [int](($ended) - $t0).TotalMilliseconds
        peak_ws = $peakWs
        root_pid = $proc.Id
        tree_text = $lastTree
        first_sample_ms = $firstSampleMs
        life_lines = $lifeLines
        start_utc = $t0.ToUniversalTime().ToString("o")
        end_utc = $ended.ToUniversalTime().ToString("o")
    }
}

function Assert-Dll([string]$Root, [string]$Expected) {
    $dll = Join-Path $Root "x64\Release\TOMWare.dll"
    if (-not (Test-Path -LiteralPath $dll)) { throw "TOMWare.dll missing: $dll" }
    $h = Get-Sha $dll
    Write-Host ("DLL SHA-256 {0}" -f $h)
    if ($h -ne $Expected.ToUpperInvariant()) { throw "DLL differs from campaign 4BBC6270. Stop." }
    return $h
}

function Get-PinVersion([string]$PinPath) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $PinPath
        $psi.Arguments = "-version"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()
        $o = $p.StandardOutput.ReadToEndAsync()
        $e = $p.StandardError.ReadToEndAsync()
        $ok = $p.WaitForExit(8000)
        if (-not $ok) { try { $p.Kill() } catch {}; return "pin_-version_timeout" }
        $txt = ""
        try { if ($o.IsCompleted) { $txt = $o.Result } } catch {}
        if (-not $txt) { try { if ($e.IsCompleted) { $txt = $e.Result } } catch {} }
        return (($txt -split "`r?`n") | Select-Object -First 3) -join " | "
    } catch {
        return ("pin_version_error {0}" -f $_.Exception.Message)
    }
}

function Invoke-OneRun {
    param([string]$SampleId, [string]$Mode, [int]$Rep, [string]$DllHash, [string]$ScriptSha)
    $sha = $Catalog[$SampleId]
    $exe = Find-HashExe $sha $RepoRoot
    if (-not $exe) { throw ("exe missing for {0} {1}" -f $SampleId, $sha) }
    $pin = Join-Path $RepoRoot "pin\intel64\bin\pin.exe"
    if (-not (Test-Path -LiteralPath $pin)) { $pin = Join-Path $RepoRoot "pin\pin.exe" }
    $dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
    $label = "{0}_{1}_r{2}" -f $SampleId, $Mode, $Rep
    $runDir = Join-Path $OutDir $label
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    $dropDir = Join-Path $runDir "drop"
    New-Item -ItemType Directory -Force -Path $dropDir | Out-Null
    $stdout = Join-Path $runDir "stdout.txt"
    $stderr = Join-Path $runDir "stderr.txt"
    $resCsv = Join-Path $runDir "resources.csv"
    $eventsPath = Join-Path $runDir "process_events.jsonl"
    $treePath = Join-Path $runDir "process_tree.txt"
    $metaPath = Join-Path $runDir "run_meta.json"
    $verdictPath = Join-Path $runDir "verdict.txt"

    Stop-Leftovers
    $knobs = ""
    $pinSha = ""
    $pinVer = ""
    if ($Mode -eq "Native") {
        $file = $exe
        $argList = @()
    } else {
        if (-not (Test-Path -LiteralPath $pin)) { throw "pin.exe missing" }
        $file = $pin
        $pinSha = Get-Sha $pin
        $pinVer = Get-PinVersion $pin
        $knobs = if ($Mode -eq "TMW0") { "-q" } else { "-do -q" }
        $argList = @("-follow_execv", "1", "-t", $dll) + $knobs.Split(" ") + @("--", $exe)
    }

    Write-Host "script_rev=r43c.1"
    Write-Host ("RUN {0} elevated=true sample_ms={1}" -f $label, $SampleMs)
    Write-Host ("  {0} {1}" -f $file, (Join-Args $argList))
    $run = Measure-Window -FileName $file -ArgumentList $argList -WorkDir $dropDir `
        -StdoutPath $stdout -StderrPath $stderr -ResCsv $resCsv -EventsPath $eventsPath `
        -WindowSec $WindowSec -SampleMs $SampleMs
    if ($null -eq $run.tree_text) { $run.tree_text = "" }
    Set-Content -Path $treePath -Value $run.tree_text -Encoding ASCII
    $treeCsv = Join-Path $runDir "process_tree.csv"
    $treeJson = Join-Path $runDir "process_tree.jsonl"
    $csvLines = New-Object System.Collections.ArrayList
    [void]$csvLines.Add("name,pid,parent_pid,depth,creation_utc")
    $jsonLines = New-Object System.Collections.ArrayList
    $nNamed = 0
    if ($null -ne $script:LastTreeRows) {
        foreach ($row in $script:LastTreeRows) {
            [void]$csvLines.Add(("{0},{1},{2},{3},{4}" -f $row.name, $row.pid, $row.parent_pid, $row.depth, $row.creation_utc))
            [void]$jsonLines.Add(('{{"name":"{0}","pid":{1},"parent_pid":{2},"depth":{3},"creation_utc":"{4}"}}' -f $row.name, $row.pid, $row.parent_pid, $row.depth, $row.creation_utc))
            if ($row.name -and $row.name -ne "?") { $nNamed++ }
        }
    }
    Set-Content -Path $treeCsv -Value $csvLines.ToArray() -Encoding ASCII
    if ($jsonLines.Count -gt 0) {
        Set-Content -Path $treeJson -Value $jsonLines.ToArray() -Encoding ASCII
    } else {
        Set-Content -Path $treeJson -Value "" -Encoding ASCII
    }
    if ($run.life_lines) {
        Set-Content -Path (Join-Path $runDir "process_lifetime.csv") -Value $run.life_lines.ToArray() -Encoding ASCII
    }

    $stdoutTxt = ""
    $stderrTxt = ""
    try { $stdoutTxt = [IO.File]::ReadAllText($stdout) } catch {}
    try { $stderrTxt = [IO.File]::ReadAllText($stderr) } catch {}
    $elev740 = ($stdoutTxt -match "error 740") -or ($stderrTxt -match "error 740") -or ($stdoutTxt -match "requer elev")
    $aliveAtWindow = [bool]$run.timed_out
    $progress = "INCONCLUSIVE"
    if ($elev740) { $progress = "PIN_LAUNCH_ELEVATION_740" }
    elseif ($aliveAtWindow) { $progress = "STILL_ALIVE_AT_WINDOW" }
    elseif ($null -ne $run.exit_code) { $progress = "EXITED_BEFORE_WINDOW" }

    $validity = "valid_attempt"
    $validityNote = "kept"
    if ($elev740) { $validity = "invalid_pin_launch_740"; $validityNote = "Pin could not start the PE (Win32 740) even under the elevated session" }
    elseif ($nNamed -eq 0 -and $Mode -ne "Native") { $validity = "inconclusive_unnamed_tree"; $validityNote = "no named parent/child at last sample; attempt kept" }
    elseif ($nNamed -eq 0 -and $Mode -eq "Native" -and $run.elapsed_ms -lt 200) { $validity = "inconclusive_native_died_before_named_sample"; $validityNote = "attempt kept; process likely died before a named CIM sample" }

    $pinMatch = if ($pinSha) { $pinSha -eq $ExpectedPinSha256.ToUpperInvariant() } else { $true }
    $meta = [ordered]@{
        campaign_id = "access_r43c_process_tree"
        script_rev = "r43c.1"
        sample_id = $SampleId
        sha256 = $sha
        mode = $Mode
        rep = $Rep
        knobs = $knobs
        window_sec = $WindowSec
        sample_ms = $SampleMs
        first_sample_ms = $run.first_sample_ms
        elevated = $true
        elevation_policy = "entire guest PowerShell session Run as administrator; all Native/TMW0/TMW_DO cells"
        dll_sha256 = $DllHash
        pin_sha256 = $pinSha
        pin_sha256_matches_campaign = $pinMatch
        pin_version = $pinVer
        script_sha256 = $ScriptSha
        pe_path = $exe
        command = ("{0} {1}" -f $file, (Join-Args $argList))
        start_utc = $run.start_utc
        end_utc = $run.end_utc
        timed_out = [bool]$run.timed_out
        exit_code = $run.exit_code
        elapsed_ms = $run.elapsed_ms
        peak_ws = $run.peak_ws
        root_pid = $run.root_pid
        n_named_last_sample = $nNamed
        progress = $progress
        process_stayed_alive_60s = [bool]$aliveAtWindow
        behavioral_progress_observed = $false
        validity = $validity
        validity_note = $validityNote
        identified = $false
        not_a_claim = "alive_is_not_progress; not Arancino; not the 9000; do not drop this attempt"
    }
    ($meta | ConvertTo-Json) | Set-Content -Path $metaPath -Encoding ASCII
    Set-Content -Path $verdictPath -Value @(
        "campaign=access_r43c_process_tree",
        "sample=$SampleId",
        "mode=$Mode",
        "rep=$Rep",
        "progress=$progress",
        "validity=$validity",
        "timed_out=$($run.timed_out)",
        "process_stayed_alive_60s=$aliveAtWindow",
        "behavioral_progress_observed=false",
        "exit_code=$($run.exit_code)",
        "elapsed_ms=$($run.elapsed_ms)",
        "peak_ws=$($run.peak_ws)",
        "n_named_last_sample=$nNamed",
        "elevated=true",
        "identified=false"
    ) -Encoding ASCII
    Write-Host ("progress {0} validity={1} elapsed_ms={2} exit={3} named={4}" -f $progress, $validity, $run.elapsed_ms, $run.exit_code, $nNamed)
    Write-Host ("out {0}" -f $runDir)
    Stop-Leftovers
}

$scriptPath = $MyInvocation.MyCommand.Path
$scriptSha = if ($scriptPath -and (Test-Path -LiteralPath $scriptPath)) { Get-Sha $scriptPath } else { "" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ($Job -eq "Prepare") {
    $null = Assert-Dll $RepoRoot $ExpectedDllSha256
    $pin = Join-Path $RepoRoot "pin\intel64\bin\pin.exe"
    if (Test-Path -LiteralPath $pin) {
        $ps = Get-Sha $pin
        Write-Host ("PIN SHA-256 {0} match={1}" -f $ps, ($ps -eq $ExpectedPinSha256.ToUpperInvariant()))
        Write-Host ("PIN version {0}" -f (Get-PinVersion $pin))
    }
    Write-Host "script_rev=r43c.1"
    Write-Host ("script_sha256 {0}" -f $scriptSha)
    Write-Host "campaign access_r43c_process_tree  window=60s  N=3  sample_ms=50  first_sample=immediate"
    Write-Host "elevated=true (uniform). Preserves access_r43 and access_r43b."
    $missing = 0
    foreach ($k in $Catalog.Keys) {
        $p = Find-HashExe $Catalog[$k] $RepoRoot
        if (-not $p) { Write-Host ("MISSING {0} {1}.exe" -f $k, $Catalog[$k]); $missing++; continue }
        Write-Host ("OK {0} {1}" -f $k, $p)
    }
    if ($missing -gt 0) { throw "Copy the three SHA-named PEs into samples\benign before RUN." }
    Write-Host "next: RUNMODE Native, copy out, restore tomware_go, Prepare, TMW0, copy, restore, TMW_DO"
    return
}

$dllHash = Assert-Dll $RepoRoot $ExpectedDllSha256

if ($Job -eq "RUNMODE") {
    foreach ($sid in @("BEN_28", "BEN_46", "BEN_47")) {
        1..$Reps | ForEach-Object {
            Invoke-OneRun -SampleId $sid -Mode $Mode -Rep $_ -DllHash $dllHash -ScriptSha $scriptSha
        }
    }
    Write-Host ("MODE {0} done. Copy {1} to host then restore tomware_go." -f $Mode, $OutDir)
    return
}

if (-not $Catalog.Contains($SampleId)) { throw "SampleId must be BEN_28, BEN_46, or BEN_47." }
Invoke-OneRun -SampleId $SampleId -Mode $Mode -Rep $Rep -DllHash $dllHash -ScriptSha $scriptSha
Write-Host ("NEXT copy {0} to host then restore tomware_go between modes" -f $OutDir)
