#Requires -Version 5.1
# Access items 1-3 together: malware-check-knob on 3 a-priori SHA.
# campaign_id=access_m3_cases  script_rev=m3c.4
# Launcher MUST be C:\TOMWare\pin\pin.exe SHA-256 920A730A…0BB819.
# Does NOT fall back to pin\intel64\bin\pin.exe (r43c / FBA632E4).
# Does NOT rerun the 9000. Does NOT change SkewMask.cpp. Does NOT set identified=true.
# TMW0 = Pin + TOMWare knobs off + counters on. Hooks of -dp/-do are NOT installed on TMW0.
# Network stays off. Prefer RUNONE: one SHA, then copy, then restore tomware_go.
# File watch is drop\ only (no TEMP recurse — that can freeze the guest).
param(
    [ValidateSet("Prepare", "RUN", "RUNONE", "RUNMODE")][string]$Job = "Prepare",
    [ValidateSet("TMW0", "TMW_DP", "TMW_DO")][string]$Mode = "TMW0",
    [ValidatePattern("^[A-Za-z0-9_]*$")][string]$SampleId = "",
    [ValidateRange(1, 9)][int]$Rep = 1,
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\access_m3_cases",
    [int]$WindowSec = 60,
    [int]$SampleMs = 200,
    [int]$Reps = 1,
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
    throw "access_m3_cases requires an elevated PowerShell (Run as administrator)."
}

# Fixed a priori from identify_summary.csv IAT leads. IAT is not a case.
# MAL_08 / MAL_13: Toolhelp + timing strings. MAL_07: SleepEx / QPC / IsDebuggerPresent.
# Do not add samples if these reject. Do not shop.
$Catalog = [ordered]@{
    MAL_08 = "1693df9d970e011cf1c827fceaf49a3724f4478bc0ed7dc50f2d90ea417b6d38"
    MAL_13 = "2a2b6b75359f4b74de136bc2c3c3a31633d3fcc169f2e2789e4d3f776ebb9e24"
    MAL_07 = "153e11471f85de3df5135b0445014698333ff40a9d6c488d291d6517eb19800d"
}

function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-ContentHashOrEmpty([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $len = [int64](Get-Item -LiteralPath $Path).Length
    if ($len -eq 0) { return "" }
    return Get-Sha $Path
}

function Join-Args([string[]]$PinArgs) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($a in @($PinArgs)) {
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
        (Join-Path $Root "malwares\infected"),
        (Join-Path $Root "samples\infected")
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
            $nThr = 0
            if ($proc) {
                try { $nThr = [int]$proc.ThreadCount } catch { $nThr = 0 }
            }
            $created = ""
            if ($proc -and $proc.CreationDate) {
                try { $created = ([DateTime]$proc.CreationDate).ToUniversalTime().ToString("o") } catch { $created = "" }
            }
            $lines.Add(("{0}{1} pid={2} parent={3} threads={4} created={5}" -f ("  " * $cur.depth), $name, $procId, $ppid, $nThr, $created))
            $script:TreeRows.Add([pscustomobject]@{
                name = $name; pid = $procId; parent_pid = $ppid; depth = [int]$cur.depth
                thread_count = $nThr; creation_utc = $created
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
        [string[]]$PinArgs,
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
    $psi.Arguments = Join-Args $PinArgs
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
    $res.Add("utc,elapsed_ms,root_alive,tree_ws,tree_ws_peak,root_ws,root_cpu_ms,n_tree,n_named,n_threads")
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
        $alive = 0; $rootWs = 0; $rootCpu = 0; $treeWs = 0; $nTree = 0; $nNamed = 0; $nThr = 0
        try {
            $pp = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($pp -and -not $pp.HasExited) {
                $alive = 1
                $rootWs = [int64]$pp.WorkingSet64
                $rootCpu = [int64]($pp.TotalProcessorTime.TotalMilliseconds)
                $treeWs += $rootWs
                $nTree++
                try { $nThr += @($pp.Threads).Count } catch {}
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
                    $nThr += [int]$row.thread_count
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
                    $ev.Add(('{{"utc":"{0}","elapsed_ms":{1},"name":"{2}","pid":{3},"parent_pid":{4},"depth":{5},"threads":{6},"creation_utc":"{7}","state":"alive"}}' -f `
                        $now.ToUniversalTime().ToString("o"), $elapsed, ($row.name -replace '"',''), $row.pid, $row.parent_pid, $row.depth, $row.thread_count, $row.creation_utc))
                }
            }
        } catch {}
        if ($treeWs -gt $peakWs) { $peakWs = $treeWs }
        $res.Add(("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $now.ToUniversalTime().ToString("o"), $elapsed, $alive, $treeWs, $peakWs, $rootWs, $rootCpu, $nTree, $nNamed, $nThr))
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
        if (-not $timedOut) { $exitUtc = $ended.ToUniversalTime().ToString("o") }
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
        start_local = $t0
    }
}

function Get-PinEngine([string]$Root) {
    foreach ($rel in @("pin\intel64\bin\pinbin.exe", "pin\intel64\bin\pin.exe")) {
        $p = Join-Path $Root $rel
        if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    }
    return $null
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

function Read-Counters([string]$Path) {
    $z = [ordered]@{
        json_ok = 0
        pe_calls = 0; pe_exam = 0; pe_filt = 0; pe_mod_exam = 0; pe_mod_filt = 0; pe_unmod = 0
        sleep_calls = 0; time_queries = 0; corrections = 0; regressions = 0
        memcmp_int = 0; memcmp_mod = 0
        env_exam = 0; env_san = 0
        ad_init = 0; ad_san = 0
    }
    if (-not (Test-Path -LiteralPath $Path)) { return $z }
    try { $j = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $z }
    $z.json_ok = 1
    try {
        $z.pe_calls = [int]$j.process_enum.calls_intercepted
        $z.pe_exam = [int]$j.process_enum.processes_examined
        $z.pe_filt = [int]$j.process_enum.processes_filtered
        $z.pe_mod_exam = [int]$j.process_enum.modules_examined
        $z.pe_mod_filt = [int]$j.process_enum.modules_filtered
        $z.pe_unmod = [int]$j.process_enum.unmodified_calls
        $z.sleep_calls = [int]$j.skew_mask.sleep_calls_intercepted
        $z.time_queries = [int]$j.skew_mask.time_queries_intercepted
        $z.corrections = [int]$j.skew_mask.corrections_applied
        $z.regressions = [int]$j.skew_mask.regressions_detected
        $z.memcmp_int = [int]$j.memcmp_mask.comparisons_intercepted
        $z.memcmp_mod = [int]$j.memcmp_mask.responses_modified
        $z.env_exam = [int]$j.sanitize_env.entries_examined
        $z.env_san = [int]$j.sanitize_env.entries_sanitized
        $z.ad_init = [int]$j.antidebug.initializations
        $z.ad_san = [int]$j.antidebug.sanitizations
    } catch {}
    return $z
}

function Get-RegSnap {
    $rows = New-Object System.Collections.Generic.List[string]
    $keys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    foreach ($k in $keys) {
        if (-not (Test-Path -LiteralPath $k)) { continue }
        try {
            $p = Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue
            if (-not $p) { continue }
            foreach ($prop in @($p.PSObject.Properties)) {
                if ($prop.Name -match '^PS') { continue }
                [void]$rows.Add(("{0}|{1}={2}" -f $k, $prop.Name, $prop.Value))
            }
        } catch {}
    }
    return $rows
}

function Get-NewFiles([datetime]$Since, [string]$DropDir, [string]$RunDir) {
    $skipExt = @(".tmp", ".temp", ".etl", ".log", ".wer")
    $rows = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $DropDir)) { return $rows }
    $cut = $Since.AddSeconds(-2)
    $files = @(Get-ChildItem -LiteralPath $DropDir -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        if ($f.LastWriteTime -lt $cut) { continue }
        if ($skipExt -contains $f.Extension.ToLowerInvariant()) { continue }
        $h = ""
        if ($f.Length -gt 0) {
            try { $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash } catch { $h = "" }
        }
        [void]$rows.Add([pscustomobject]@{ path = $f.FullName; length = $f.Length; sha256 = $h })
    }
    return $rows
}

function Get-TcpSnap {
    $rows = New-Object System.Collections.Generic.List[string]
    try {
        $cons = @(Get-NetTCPConnection -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq "Established" -and $_.RemoteAddress -notin @("127.0.0.1", "::1", "0.0.0.0") })
        foreach ($c in $cons) {
            [void]$rows.Add(("{0},{1},{2},{3}" -f $c.OwningProcess, $c.RemoteAddress, $c.RemotePort, $c.State))
        }
    } catch {}
    return $rows
}

function Count-AppDescendants {
    $skip = @("pin.exe", "pinbin.exe", "conhost.exe", "?")
    $n = 0
    $names = New-Object System.Collections.Generic.List[string]
    if ($null -eq $script:LastTreeRows) { return @{ n = 0; names = "" } }
    foreach ($row in $script:LastTreeRows) {
        $nm = [string]$row.name
        if (-not $nm) { continue }
        if ($skip -contains $nm.ToLowerInvariant()) { continue }
        if ($nm -match '^[0-9a-fA-F]{64}\.exe$') { continue }
        $n++
        $names.Add($nm)
    }
    return @{ n = $n; names = ($names -join "|") }
}

function Invoke-OneRun {
    param([string]$SampleId, [string]$Mode, [int]$Rep, [string]$DllHash, [string]$ScriptSha)
    $sha = $Catalog[$SampleId]
    $exe = Find-HashExe $sha $RepoRoot
    if (-not $exe) { throw ("exe missing for {0} {1}" -f $SampleId, $sha) }
    $pin = Join-Path $RepoRoot "pin\pin.exe"
    $engine = Get-PinEngine $RepoRoot
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
    $mcf = Join-Path $runDir "module_events.json"
    $newFilesPath = Join-Path $runDir "new_files.csv"
    $regPath = Join-Path $runDir "registry_delta.txt"
    $tcpPath = Join-Path $runDir "tcp_established.csv"
    if (Test-Path -LiteralPath $mcf) { Remove-Item -LiteralPath $mcf -Force }

    Stop-Leftovers
    if (-not (Test-Path -LiteralPath $pin)) { throw "Campaign launcher missing: pin\pin.exe" }
    $pinSha = Get-Sha $pin
    if ($pinSha -ne $ExpectedPinSha256.ToUpperInvariant()) {
        throw ("pin\pin.exe SHA-256 {0} != campaign 920A730A. Refusing intel64 fallback." -f $pinSha)
    }
    $pinVer = Get-PinVersion $pin
    $engineSha = if ($engine -and (Test-Path -LiteralPath $engine)) { Get-Sha $engine } else { "" }

    $knobArgs = @("-q", "-mc", "1", "-mcf", $mcf)
    if ($Mode -eq "TMW_DP") { $knobArgs = @("-dp") + $knobArgs }
    elseif ($Mode -eq "TMW_DO") { $knobArgs = @("-do") + $knobArgs }
    $knobs = $knobArgs -join " "
    $argList = @("-follow_execv", "1", "-t", $dll) + $knobArgs + @("--", $exe)

    $regBefore = @(Get-RegSnap)
    Write-Host "script_rev=m3c.4"
    Write-Host ("RUN {0} elevated=true sample_ms={1} window={2}" -f $label, $SampleMs, $WindowSec)
    Write-Host ("  {0} {1}" -f $pin, (Join-Args $argList))
    $run = Measure-Window -FileName $pin -PinArgs $argList -WorkDir $dropDir `
        -StdoutPath $stdout -StderrPath $stderr -ResCsv $resCsv -EventsPath $eventsPath `
        -WindowSec $WindowSec -SampleMs $SampleMs
    if ($null -eq $run.tree_text) { $run.tree_text = "" }
    Set-Content -Path $treePath -Value $run.tree_text -Encoding ASCII

    $treeCsv = Join-Path $runDir "process_tree.csv"
    $treeJson = Join-Path $runDir "process_tree.jsonl"
    $csvLines = New-Object System.Collections.ArrayList
    [void]$csvLines.Add("name,pid,parent_pid,depth,thread_count,creation_utc")
    $jsonLines = New-Object System.Collections.ArrayList
    $nNamed = 0
    if ($null -ne $script:LastTreeRows) {
        foreach ($row in $script:LastTreeRows) {
            [void]$csvLines.Add(("{0},{1},{2},{3},{4},{5}" -f $row.name, $row.pid, $row.parent_pid, $row.depth, $row.thread_count, $row.creation_utc))
            [void]$jsonLines.Add(('{{"name":"{0}","pid":{1},"parent_pid":{2},"depth":{3},"threads":{4},"creation_utc":"{5}"}}' -f $row.name, $row.pid, $row.parent_pid, $row.depth, $row.thread_count, $row.creation_utc))
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

    $newRows = Get-NewFiles -Since $run.start_local -DropDir $dropDir -RunDir $runDir
    if ($newRows.Count -gt 0) {
        $newRows | Export-Csv -Path $newFilesPath -NoTypeInformation -Encoding ASCII
    } else {
        Set-Content -Path $newFilesPath -Value "path,length,sha256" -Encoding ASCII
    }
    $regAfter = @(Get-RegSnap)
    $regBeforeArr = @($regBefore)
    $regDelta = @($regAfter | Where-Object { $regBeforeArr -notcontains $_ })
    $regLines = New-Object System.Collections.Generic.List[string]
    [void]$regLines.Add("before_count=$($regBeforeArr.Count)")
    [void]$regLines.Add("after_count=$($regAfter.Count)")
    [void]$regLines.Add("delta_count=$($regDelta.Count)")
    foreach ($line in $regDelta) { [void]$regLines.Add([string]$line) }
    Set-Content -Path $regPath -Value $regLines.ToArray() -Encoding ASCII
    $tcp = Get-TcpSnap
    Set-Content -Path $tcpPath -Value (@("owning_pid,remote,port,state") + $tcp) -Encoding ASCII

    $ctr = Read-Counters $mcf
    $app = Count-AppDescendants
    $stdoutHash = Get-ContentHashOrEmpty $stdout
    $stderrHash = Get-ContentHashOrEmpty $stderr
    $stdoutLen = if (Test-Path -LiteralPath $stdout) { [int64](Get-Item -LiteralPath $stdout).Length } else { 0 }
    $stderrLen = if (Test-Path -LiteralPath $stderr) { [int64](Get-Item -LiteralPath $stderr).Length } else { 0 }

    $hookSeen = (($ctr.pe_calls + $ctr.pe_mod_exam + $ctr.sleep_calls + $ctr.time_queries + $ctr.memcmp_int + $ctr.env_exam + $ctr.ad_init) -gt 0)
    $resultChanged = (($ctr.pe_filt + $ctr.pe_mod_filt + $ctr.corrections + $ctr.memcmp_mod + $ctr.env_san + $ctr.ad_san) -gt 0)
    $extraAbs = (($newRows.Count -gt 0) -or ($regDelta.Count -gt 0) -or ($tcp.Count -gt 0) -or ([int]$app.n -gt 0))

    $aliveAtWindow = [bool]$run.timed_out
    $progress = if ($aliveAtWindow) { "STILL_ALIVE_AT_WINDOW" } else { "EXITED_BEFORE_WINDOW" }
    $verdict = "REJECT_NO_HOOK"
    $why = "No module counter incremented. IAT/strings are not a case. Alive is not progress."
    if ($hookSeen -and -not $resultChanged) {
        $verdict = "HOOK_SEEN_NO_RESULT_CHANGE"
        $why = "A hook fired but no filter/correction/sanitize count. Not identified."
    } elseif ($hookSeen -and $resultChanged -and -not $extraAbs) {
        $verdict = "HOOK_AND_CHANGE_NO_ARTIFACT"
        $why = "Hook + result change, no hashed extra file/reg/tcp/app-child. Not identified."
    } elseif ($hookSeen -and $resultChanged -and $extraAbs) {
        $verdict = "CHAIN_CANDIDATE_REVIEW"
        $why = "Hook + change + absolute extra signal. Still identified=false until host review vs TMW0. pin/conhost tree is not extra."
    }

    $pinMatch = $pinSha -eq $ExpectedPinSha256.ToUpperInvariant()
    $meta = [ordered]@{
        campaign_id = "access_m3_cases"
        script_rev = "m3c.4"
        file_watch = "drop_only_no_temp_recurse"
        pin_path = $pin
        pin_engine_path = $engine
        pin_engine_sha256 = $engineSha
        sample_id = $SampleId
        sha256 = $sha
        mode = $Mode
        rep = $Rep
        knobs = $knobs
        window_sec = $WindowSec
        sample_ms = $SampleMs
        first_sample_ms = $run.first_sample_ms
        elevated = $true
        dll_sha256 = $DllHash
        pin_sha256 = $pinSha
        pin_sha256_matches_campaign = $pinMatch
        pin_version = $pinVer
        script_sha256 = $ScriptSha
        pe_path = $exe
        command = ("{0} {1}" -f $pin, (Join-Args $argList))
        start_utc = $run.start_utc
        end_utc = $run.end_utc
        timed_out = [bool]$run.timed_out
        exit_code = $run.exit_code
        elapsed_ms = $run.elapsed_ms
        peak_ws = $run.peak_ws
        root_pid = $run.root_pid
        n_named_last_sample = $nNamed
        n_app_descendants = [int]$app.n
        app_descendant_names = [string]$app.names
        n_new_files = $newRows.Count
        n_registry_delta = $regDelta.Count
        n_tcp_established = $tcp.Count
        stdout_bytes = $stdoutLen
        stderr_bytes = $stderrLen
        stdout_sha256 = $stdoutHash
        stderr_sha256 = $stderrHash
        json_ok = [int]$ctr.json_ok
        pe_calls_intercepted = [int]$ctr.pe_calls
        pe_processes_filtered = [int]$ctr.pe_filt
        pe_modules_examined = [int]$ctr.pe_mod_exam
        pe_modules_filtered = [int]$ctr.pe_mod_filt
        sleep_calls_intercepted = [int]$ctr.sleep_calls
        time_queries_intercepted = [int]$ctr.time_queries
        corrections_applied = [int]$ctr.corrections
        memcmp_intercepted = [int]$ctr.memcmp_int
        hook_seen = [bool]$hookSeen
        result_changed = [bool]$resultChanged
        extra_signal_absolute = [bool]$extraAbs
        progress = $progress
        process_stayed_alive_60s = [bool]$aliveAtWindow
        behavioral_progress_observed = $false
        verdict = $verdict
        identified = $false
        chain_complete = $false
        validity = "valid_attempt"
        why = $why
        not_a_claim = "alive_is_not_progress; IAT_is_not_a_case; not_the_100; not_Arancino; not_the_9000; identified_stays_false"
    }
    ($meta | ConvertTo-Json) | Set-Content -Path $metaPath -Encoding ASCII
    Set-Content -Path $verdictPath -Value @(
        "campaign=access_m3_cases",
        "sample=$SampleId",
        "mode=$Mode",
        "rep=$Rep",
        "verdict=$verdict",
        "hook_seen=$hookSeen",
        "result_changed=$resultChanged",
        "extra_signal_absolute=$extraAbs",
        "behavioral_progress_observed=false",
        "identified=false",
        "chain_complete=false",
        "timed_out=$($run.timed_out)",
        "exit_code=$($run.exit_code)",
        "elapsed_ms=$($run.elapsed_ms)",
        "pe_calls_intercepted=$($ctr.pe_calls)",
        "pe_processes_filtered=$($ctr.pe_filt)",
        "sleep_calls_intercepted=$($ctr.sleep_calls)",
        "time_queries_intercepted=$($ctr.time_queries)",
        "corrections_applied=$($ctr.corrections)",
        "n_new_files=$($newRows.Count)",
        "n_registry_delta=$($regDelta.Count)",
        "n_tcp_established=$($tcp.Count)",
        "n_app_descendants=$($app.n)",
        "why=$why"
    ) -Encoding ASCII
    Write-Host ("verdict {0} hook={1} changed={2} extra={3} elapsed_ms={4}" -f $verdict, $hookSeen, $resultChanged, $extraAbs, $run.elapsed_ms)
    Write-Host ("out {0}" -f $runDir)
    Stop-Leftovers
}

$scriptPath = $MyInvocation.MyCommand.Path
$scriptSha = if ($scriptPath -and (Test-Path -LiteralPath $scriptPath)) { Get-Sha $scriptPath } else { "" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ($Job -eq "Prepare") {
    $null = Assert-Dll $RepoRoot $ExpectedDllSha256
    $pin = Join-Path $RepoRoot "pin\pin.exe"
    if (-not (Test-Path -LiteralPath $pin)) { throw "Campaign launcher missing: pin\pin.exe" }
    $ps = Get-Sha $pin
    Write-Host ("PIN launcher {0}" -f $pin)
    Write-Host ("PIN SHA-256 {0} match={1}" -f $ps, ($ps -eq $ExpectedPinSha256.ToUpperInvariant()))
    if ($ps -ne $ExpectedPinSha256.ToUpperInvariant()) {
        throw "Prepare refused: pin\pin.exe is not 920A730A. Do not use intel64\bin\pin.exe."
    }
    Write-Host ("PIN version {0}" -f (Get-PinVersion $pin))
    $eng = Get-PinEngine $RepoRoot
    if ($eng) { Write-Host ("PIN engine {0} SHA-256 {1} (not the command)" -f $eng, (Get-Sha $eng)) }
    Write-Host "script_rev=m3c.4"
    Write-Host ("script_sha256 {0}" -f $scriptSha)
    Write-Host "campaign access_m3_cases  window=60s  N=1  sample_ms=200  launcher=pin\pin.exe"
    Write-Host "file watch = drop only (no TEMP recurse). Prefer RUNONE. Network off. identified stays false."
    $missing = 0
    foreach ($k in $Catalog.Keys) {
        $p = Find-HashExe $Catalog[$k] $RepoRoot
        if (-not $p) { Write-Host ("MISSING {0} {1}.exe" -f $k, $Catalog[$k]); $missing++; continue }
        Write-Host ("OK {0} {1}" -f $k, $p)
    }
    if ($missing -gt 0) { throw "Copy the three SHA-named PEs into malwares\infected before RUN." }
    Write-Host "next: RUNONE MAL_07 TMW0 (smallest first). Copy that folder, restore tomware_go."
    return
}

$dllHash = Assert-Dll $RepoRoot $ExpectedDllSha256

if ($Job -eq "RUNONE") {
    if (-not $Catalog.Contains($SampleId)) { throw "RUNONE requires -SampleId MAL_07, MAL_13, or MAL_08." }
    Invoke-OneRun -SampleId $SampleId -Mode $Mode -Rep $Rep -DllHash $dllHash -ScriptSha $scriptSha
    Write-Host ("COPY NOW {0}\{1}_{2}_r{3}  then restore tomware_go." -f $OutDir, $SampleId, $Mode, $Rep)
    return
}

if ($Job -eq "RUNMODE") {
    Write-Host "WARNING: RUNMODE runs all three. Prefer RUNONE. Order is MAL_07, MAL_13, MAL_08."
    foreach ($sid in @("MAL_07", "MAL_13", "MAL_08")) {
        foreach ($repNum in 1..$Reps) {
            Invoke-OneRun -SampleId $sid -Mode $Mode -Rep $repNum -DllHash $dllHash -ScriptSha $scriptSha
            Write-Host ("finished {0}_{1}_r{2}. Copy that folder if the guest still responds." -f $sid, $Mode, $repNum)
        }
    }
    Write-Host ("MODE {0} done. Copy {1} to host then restore tomware_go." -f $Mode, $OutDir)
    return
}

if (-not $Catalog.Contains($SampleId)) { throw "SampleId must be MAL_08, MAL_13, or MAL_07." }
Invoke-OneRun -SampleId $SampleId -Mode $Mode -Rep $Rep -DllHash $dllHash -ScriptSha $scriptSha
Write-Host ("NEXT copy {0} to host then restore tomware_go between modes" -f $OutDir)
