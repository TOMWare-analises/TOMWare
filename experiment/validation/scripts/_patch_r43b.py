from pathlib import Path

src = Path(__file__).with_name("Run-AccessR43.ps1")
dst = Path(__file__).with_name("Run-AccessR43b.ps1")
t = src.read_text(encoding="utf-8")
t = t.replace("access_r43_skewmask_diag", "access_r43b_process_tree")
t = t.replace(
    '[string]$OutDir = "C:\\TOMWare\\access_r43"',
    '[string]$OutDir = "C:\\TOMWare\\access_r43b"',
)
t = t.replace(
    "# Access R4.3 diagnostic. Campaign id access_r43b_process_tree.",
    "# Access R4.3b process-tree diagnostic. Campaign id access_r43b_process_tree.\n"
    "# Preserves access_r43_skewmask_diag. Fixes automatic $pid (use $procId).",
)
old = """            $pid = [int]$cur.pid
            if ($seen.ContainsKey($pid)) { continue }
            $seen[$pid] = $true
            $proc = $all | Where-Object { [int]$_.ProcessId -eq $pid } | Select-Object -First 1
            $name = if ($proc) { $proc.Name } else { "?" }
            $lines.Add(("{0}{1} pid={2}" -f ("  " * $cur.depth), $name, $pid))
            if ($byParent.ContainsKey($pid)) {
                foreach ($ch in $byParent[$pid]) { $stack.Push(@{ pid = [int]$ch.ProcessId; depth = $cur.depth + 1 }) }
            }"""
new = """            $procId = [int]$cur.pid
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
            }"""
if old not in t:
    raise SystemExit("pattern not found")
t = t.replace(old, new)
t = t.replace(
    "function Get-TreeText([int]$RootPid) {\n    $lines = New-Object System.Collections.Generic.List[string]",
    "function Get-TreeText([int]$RootPid) {\n    $script:TreeRows = New-Object System.Collections.Generic.List[object]\n    $lines = New-Object System.Collections.Generic.List[string]",
)
t = t.replace(
    "        $lastTree = Get-TreeText -RootPid $proc.Id",
    "        $lastTree = Get-TreeText -RootPid $proc.Id\n            $script:LastTreeRows = $script:TreeRows",
)
# write csv/json after tree_text
needle = 'Set-Content -Path $treePath -Value $run.tree_text -Encoding ASCII'
insert = r'''Set-Content -Path $treePath -Value $run.tree_text -Encoding ASCII
$treeCsv = Join-Path $runDir "process_tree.csv"
$treeJson = Join-Path $runDir "process_tree.jsonl"
$rows = @($script:LastTreeRows)
if ($rows.Count -gt 0) {
    $rows | Export-Csv -Path $treeCsv -NoTypeInformation -Encoding ASCII
    $rows | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -Path $treeJson -Encoding ASCII
} else {
    Set-Content -Path $treeCsv -Value "name,pid,parent_pid,depth" -Encoding ASCII
    Set-Content -Path $treeJson -Value "" -Encoding ASCII
}'''
if needle not in t:
    raise SystemExit("tree write not found")
t = t.replace(needle, insert)
t = t.replace("copy OutDir to host and restore tomware_go BETWEEN modes",
              "copy C:\\TOMWare\\access_r43b to host; do not overwrite access_r43")
dst.write_text(t, encoding="utf-8")
print("WROTE", dst, "bytes", dst.stat().st_size)
