#Requires -Version 5.1
# M3 gate: 10 s Toolhelp under -dp -mc. Does NOT set identified=true.
# IAT/string/timeout/still-alive are not a case. Campaign DLL 4BBC6270 only.
param(
    [ValidateSet("Smoke", "Gate")]
    [string]$Phase = "Smoke",
    [string]$SampleId = "MAL_08",
    [string]$Sha256 = "",
    [string]$RepoRoot = "C:\TOMWare",
    [string]$OutDir = "C:\TOMWare\m3_gate",
    [int]$WindowSec = 10,
    [int]$SampleMs = 200
)
$ErrorActionPreference = "Stop"
$CampaignPrefix = "4BBC6270"

$catalog = @{
    MAL_08 = "1693df9d970e011cf1c827fceaf49a3724f4478bc0ed7dc50f2d90ea417b6d38"
    MAL_13 = "2a2b6b75359f4b74de136bc2c3c3a31633d3fcc169f2e2789e4d3f776ebb9e24"
    MAL_01 = "022066efc497ee51fc55bfbac818f0c8c0194b4fcd6dc89815c30b6ca11d286c"
    MAL_05 = "0fcc376c2edc128ecccba45376cdcdadf26e6f63134a0eff7d86be57775c891e"
    MAL_06 = "10c12ffde56d43a4f999b96abfe7b1d95ca91366a0fa83094bf23d02f9fc03e5"
    MAL_11 = "1df0c1d9e2deef45b585fefd1a03865a24b0ca98a4f997d2158dae8b480970b6"
    BEN_17 = "096473a4a449d224ac737fd6bb0f326c0aa7f6d713c57f6a728a1bd362671ebc"
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

function Find-SampleExe([string]$Sha256, [string]$Root) {
    $shaU = $Sha256.ToUpperInvariant()
    $shaL = $Sha256.ToLowerInvariant()
    $dirs = @(
        (Join-Path $Root "malwares\infected"),
        (Join-Path $Root "samples\infected"),
        (Join-Path $Root "malwares\benign"),
        (Join-Path $Root "samples\benign"),
        (Join-Path $Root "Resultados\Apps-Teste")
    )
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { continue }
        foreach ($n in @("$shaL.exe", "$shaU.exe", $shaL, $shaU)) {
            $p = Join-Path $d $n
            if (Test-Path $p) { return (Resolve-Path $p).Path }
        }
    }
    return $null
}

function Get-FileSnap([string[]]$Dirs) {
    $rows = @()
    $skipExt = @(".tmp", ".temp", ".etl", ".log")
    foreach ($d in $Dirs) {
        if (-not (Test-Path $d)) { continue }
        Get-ChildItem -Path $d -File -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($skipExt -contains $_.Extension.ToLowerInvariant()) { return }
                $hash = $null
                try {
                    $hash = (Get-FileHash $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                } catch {
                    return
                }
                $rows += [PSCustomObject]@{
                    path = $_.FullName
                    length = $_.Length
                    sha256 = $hash
                }
            }
    }
    return $rows
}

function Read-PeCounters([string]$path) {
    $z = @{ json_ok = 0; pe_calls = 0; pe_exam = 0; pe_filt = 0; pe_mod_exam = 0; pe_mod_filt = 0 }
    if (-not (Test-Path $path)) { return $z }
    try { $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $z }
    return @{
        json_ok = 1
        pe_calls = [int]$j.process_enum.calls_intercepted
        pe_exam = [int]$j.process_enum.processes_examined
        pe_filt = [int]$j.process_enum.processes_filtered
        pe_mod_exam = [int]$j.process_enum.modules_examined
        pe_mod_filt = [int]$j.process_enum.modules_filtered
    }
}

function Get-TreeText([int]$RootPid) {
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
            $pid = [int]$cur.pid
            if ($seen.ContainsKey($pid)) { continue }
            $seen[$pid] = $true
            $proc = $all | Where-Object { [int]$_.ProcessId -eq $pid } | Select-Object -First 1
            $name = if ($proc) { $proc.Name } else { "?" }
            $lines.Add(("{0}{1} pid={2}" -f ("  " * $cur.depth), $name, $pid))
            if ($byParent.ContainsKey($pid)) {
                foreach ($ch in $byParent[$pid]) { $stack.Push(@{ pid = [int]$ch.ProcessId; depth = $cur.depth + 1 }) }
            }
        }
    } catch {
        $lines.Add(("tree_error {0}" -f $_.Exception.Message))
    }
    return ($lines -join "`r`n")
}

function Measure-Window {
    param(
        [string]$PinExe,
        [string[]]$PinArgs,
        [string]$WorkDir,
        [string]$StdoutPath,
        [string]$StderrPath,
        [string]$ResCsv,
        [int]$WindowSec,
        [int]$SampleMs
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $PinExe
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
    $outFs = [IO.File]::Open($StdoutPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $errFs = [IO.File]::Open($StderrPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $outCopy = $proc.StandardOutput.BaseStream.CopyToAsync($outFs)
    $errCopy = $proc.StandardError.BaseStream.CopyToAsync($errFs)

    $res = New-Object System.Collections.Generic.List[string]
    $res.Add("utc,elapsed_ms,pin_alive,tree_ws,tree_ws_peak,pin_ws,pin_cpu_ms,n_tree")
    $deadline = $t0.AddSeconds($WindowSec)
    $peakWs = [int64]0
    $lastTree = ""
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds $SampleMs
        $elapsed = [int]((Get-Date) - $t0).TotalMilliseconds
        $pinAlive = 0
        $pinWs = 0
        $pinCpu = 0
        $treeWs = 0
        $nTree = 0
        try {
            $pp = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($pp -and -not $pp.HasExited) {
                $pinAlive = 1
                $pinWs = [int64]$pp.WorkingSet64
                $pinCpu = [int64]($pp.TotalProcessorTime.TotalMilliseconds)
                $treeWs += $pinWs
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
        } catch {}
        if ($treeWs -gt $peakWs) { $peakWs = $treeWs }
        $res.Add(("{0},{1},{2},{3},{4},{5},{6},{7}" -f (Get-Date).ToUniversalTime().ToString("o"), $elapsed, $pinAlive, $treeWs, $peakWs, $pinWs, $pinCpu, $nTree))
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
        pin_pid = $proc.Id
        tree_text = $lastTree
    }
}

$pin = Join-Path $RepoRoot "pin\pin.exe"
$dll = Join-Path $RepoRoot "x64\Release\TOMWare.dll"
if (-not (Test-Path $pin)) { throw "pin.exe missing: $pin" }
if (-not (Test-Path $dll)) { throw "TOMWare.dll missing: $dll" }

$dllHash = (Get-FileHash $dll -Algorithm SHA256).Hash.ToUpperInvariant()
Write-Host ("DLL SHA-256 {0}" -f $dllHash)
if (-not $dllHash.StartsWith($CampaignPrefix)) {
    throw ("REFUSE: campaign DLL must start with {0}. Got {1}. Restore 4BBC6270." -f $CampaignPrefix, $dllHash)
}
$pinHash = (Get-FileHash $pin -Algorithm SHA256).Hash.ToUpperInvariant()
Write-Host ("pin.exe SHA-256 {0}" -f $pinHash)

$pinDir = Split-Path -Parent $pin
$pinBin = Join-Path $pinDir "intel64\bin"
$env:PIN_ROOT = $pinDir
if (Test-Path $pinBin) {
    $env:PATH = ($pinBin + ";" + $pinDir + ";" + $env:PATH)
    $pinBinExe = Join-Path $pinBin "pin.exe"
    if (Test-Path $pinBinExe) { $pin = $pinBinExe }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ($Phase -eq "Smoke") {
    $label = "SMOKE_TestProcessEnum"
    $exe = Join-Path $RepoRoot "Resultados\Apps-Teste\TestProcessEnum.exe"
    if (-not (Test-Path $exe)) { throw "TestProcessEnum.exe missing: $exe" }
    $sha = (Get-FileHash $exe -Algorithm SHA256).Hash
} else {
    if ($Sha256) {
        $label = $SampleId
        $sha = $Sha256.ToLowerInvariant()
    } else {
        if (-not $catalog.ContainsKey($SampleId)) {
            throw ("unknown SampleId {0}; pass -Sha256" -f $SampleId)
        }
        $label = $SampleId
        $sha = $catalog[$SampleId]
    }
    $exe = Find-SampleExe $sha $RepoRoot
    if (-not $exe) { throw ("sample exe missing for {0} {1}" -f $label, $sha) }
}

$runDir = Join-Path $OutDir $label
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$dropDir = Join-Path $runDir "drop"
New-Item -ItemType Directory -Force -Path $dropDir | Out-Null
$mcf = Join-Path $runDir "module_events.json"
$stdout = Join-Path $runDir "stdout.txt"
$stderr = Join-Path $runDir "stderr.txt"
$resCsv = Join-Path $runDir "resources.csv"
$treePath = Join-Path $runDir "process_tree.txt"
$metaPath = Join-Path $runDir "run_meta.json"
$verdictPath = Join-Path $runDir "verdict.txt"
$newFilesPath = Join-Path $runDir "new_files.csv"

if (Test-Path $mcf) { Remove-Item $mcf -Force }

$watch = @($dropDir)
$before = Get-FileSnap $watch
Stop-Leftovers

$args = @(
    "-follow_execv", "1",
    "-t", $dll,
    "-dp", "-q",
    "-mc", "1", "-mcf", $mcf,
    "--", $exe
)
Write-Host ("RUN {0}" -f $label)
Write-Host ("  {0} {1}" -f $pin, (Join-Args $args))

$run = Measure-Window -PinExe $pin -PinArgs $args -WorkDir $dropDir `
    -StdoutPath $stdout -StderrPath $stderr -ResCsv $resCsv `
    -WindowSec $WindowSec -SampleMs $SampleMs

Start-Sleep -Milliseconds 500
Set-Content -Path $treePath -Value $run.tree_text -Encoding ASCII

$after = Get-FileSnap $watch
$beforeSet = @{}
foreach ($b in $before) { $beforeSet[$b.path] = $b.sha256 }
$newRows = @()
foreach ($a in $after) {
    if ($beforeSet.ContainsKey($a.path)) { continue }
    if ($a.path -like ($runDir + "*")) { continue }
    $newRows += $a
}
if ($newRows.Count -gt 0) {
    $newRows | Export-Csv -Path $newFilesPath -NoTypeInformation -Encoding ASCII
} else {
    Set-Content -Path $newFilesPath -Value "path,length,sha256" -Encoding ASCII
}

$pe = Read-PeCounters $mcf
$peCalls = [int]$pe.pe_calls
$peMod = [int]$pe.pe_mod_exam
$toolhelp = ($peCalls -gt 0) -or ($peMod -gt 0)

$verdict = "REJECT_NO_TOOLHELP"
$why = "Process32*/Module32* not intercepted in {0}s under -dp -mc. IAT is not a case. Do not run NAT/TMW0/TMW_DP." -f $WindowSec
if ($Phase -eq "Smoke") {
    if ($toolhelp -and ([int]$pe.pe_filt -gt 0 -or [int]$pe.pe_mod_filt -gt 0)) {
        $verdict = "SMOKE_OK"
        $why = "Oracle TestProcessEnum called Toolhelp and the hook filtered pin.exe. Harness works. This is NOT a real-sample case."
    } else {
        $verdict = "SMOKE_FAIL"
        $why = "Oracle did not show pe_calls/pe_filt. Stop. Check DLL knobs -dp -mc."
    }
} elseif ($toolhelp) {
    $verdict = "GATE_TOOLHELP_SEEN"
    $why = "Toolhelp/Module32 ran (counter). NOT identified=true: no RVA, no pin.exe compare, no extra hashed artifact yet. Copy this folder. Do not claim a case. Triad only after review."
}

$meta = [ordered]@{
    phase = $Phase
    sample_id = $label
    sha256 = $sha
    pe_path = $exe
    dll_sha256 = $dllHash
    pin_sha256 = $pinHash
    knobs = "-dp -q -mc 1"
    window_sec = $WindowSec
    timed_out = [bool]$run.timed_out
    exit_code = $run.exit_code
    elapsed_ms = $run.elapsed_ms
    peak_ws = $run.peak_ws
    json_ok = [int]$pe.json_ok
    pe_calls_intercepted = $peCalls
    pe_processes_examined = [int]$pe.pe_exam
    pe_processes_filtered = [int]$pe.pe_filt
    pe_modules_examined = $peMod
    pe_modules_filtered = [int]$pe.pe_mod_filt
    n_new_files = $newRows.Count
    verdict = $verdict
    identified = $false
    why = $why
}
($meta | ConvertTo-Json) | Set-Content -Path $metaPath -Encoding ASCII

$vt = @(
    "verdict=$verdict",
    "identified=false",
    "sample=$label",
    "sha256=$sha",
    "dll=$dllHash",
    "pe_calls_intercepted=$peCalls",
    "pe_processes_filtered=$($pe.pe_filt)",
    "pe_modules_examined=$peMod",
    "timed_out=$($run.timed_out)",
    "exit_code=$($run.exit_code)",
    "n_new_files=$($newRows.Count)",
    "why=$why"
)
Set-Content -Path $verdictPath -Value $vt -Encoding ASCII

Write-Host "----"
Write-Host ("verdict {0}" -f $verdict)
Write-Host $why
Write-Host ("pe_calls={0} pe_filt={1} pe_mod={2} json_ok={3}" -f $peCalls, $pe.pe_filt, $peMod, $pe.json_ok)
Write-Host ("out {0}" -f $runDir)
Stop-Leftovers
