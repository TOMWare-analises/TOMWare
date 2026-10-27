#Requires -Version 5.1
<#
.SYNOPSIS
  Coletor modular de metricas de processo, memoria, CPU, I/O e modulos (TOMWare.M).
  Desenvolvido com chamadas nativas de alta performance (sem consultas WMI lentas no loop continuo).
#>

$win32IoDefinition = @"
using System;
using System.Runtime.InteropServices;

namespace TomwareCollector {
    public static class NativeMethods {
        [StructLayout(LayoutKind.Sequential)]
        public struct IO_COUNTERS {
            public ulong ReadOperationCount;
            public ulong WriteOperationCount;
            public ulong OtherOperationCount;
            public ulong ReadTransferCount;
            public ulong WriteTransferCount;
            public ulong OtherTransferCount;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetProcessIoCounters(IntPtr hProcess, out IO_COUNTERS lpIoCounters);
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]"TomwareCollector.NativeMethods").Type) {
    Add-Type -TypeDefinition $win32IoDefinition -ErrorAction SilentlyContinue
}

function Get-ChildProcessIdsSafe {
    param(
        [int]$ParentPid,
        [System.Collections.Generic.HashSet[int]]$Visited = $null
    )
    if ($ParentPid -le 0) { return @() }
    if ($Visited -eq $null) {
        $Visited = [System.Collections.Generic.HashSet[int]]::new()
    }
    if ($Visited.Contains($ParentPid)) { return @() }
    [void]$Visited.Add($ParentPid)

    $children = @()
    try {
        $procs = Get-CimInstance -ClassName Win32_Process -Filter "ParentProcessId = $ParentPid" -ErrorAction SilentlyContinue
        foreach ($proc in $procs) {
            $cid = [int]$proc.ProcessId
            if ($cid -gt 0 -and -not $Visited.Contains($cid)) {
                $children += $cid
                $children += Get-ChildProcessIdsSafe -ParentPid $cid -Visited $Visited
            }
        }
    } catch {}
    return @($children | Select-Object -Unique)
}

function Get-ProcessMetricsSample {
    param(
        [int]$RootPid,
        [string]$SampleBaseName = ""
    )

    $totalWs = [long]0
    $totalPriv = [long]0
    $totalCpuUserMs = [double]0
    $totalCpuKernelMs = [double]0
    $totalThreads = 0
    $totalHandles = 0
    $activeProcesses = 0
    $trackedPids = [System.Collections.Generic.HashSet[int]]::new()
    $childPids = @()

    # 1. Processo raiz direto via .NET (5 ms)
    if ($RootPid -gt 0) {
        try {
            $p = Get-Process -Id $RootPid -ErrorAction SilentlyContinue
            if ($p -and -not $p.HasExited) {
                $p.Refresh()
                $totalWs += [long]$p.WorkingSet64
                $totalPriv += [long]$p.PrivateMemorySize64
                $totalCpuUserMs += $p.UserProcessorTime.TotalMilliseconds
                $totalCpuKernelMs += $p.PrivilegedProcessorTime.TotalMilliseconds
                $totalThreads += $p.Threads.Count
                $totalHandles += $p.HandleCount
                $activeProcesses++
                [void]$trackedPids.Add($RootPid)
            }
        } catch {}
    }

    # 2. Processos associados da arvore por nome rapido (pin, pinbin e executavel da amostra)
    $namesToQuery = @("pin", "pinbin")
    if ($SampleBaseName) {
        $namesToQuery += $SampleBaseName
    }

    foreach ($name in ($namesToQuery | Select-Object -Unique)) {
        try {
            $procList = Get-Process -Name $name -ErrorAction SilentlyContinue
            foreach ($p in $procList) {
                if ($p -and -not $p.HasExited -and -not $trackedPids.Contains($p.Id)) {
                    try {
                        $p.Refresh()
                        $totalWs += [long]$p.WorkingSet64
                        $totalPriv += [long]$p.PrivateMemorySize64
                        $totalCpuUserMs += $p.UserProcessorTime.TotalMilliseconds
                        $totalCpuKernelMs += $p.PrivilegedProcessorTime.TotalMilliseconds
                        $totalThreads += $p.Threads.Count
                        $totalHandles += $p.HandleCount
                        $activeProcesses++
                        [void]$trackedPids.Add($p.Id)
                        $childPids += $p.Id
                    } catch {}
                }
            }
        } catch {}
    }

    return [PSCustomObject]@{
        TimestampUtc        = (Get-Date).ToUniversalTime().ToString("o")
        ActiveProcessCount  = $activeProcesses
        ChildPids           = $childPids
        TotalWorkingSetBytes = $totalWs
        TotalPrivateBytes   = $totalPriv
        CpuUserMs           = [Math]::Round($totalCpuUserMs, 2)
        CpuKernelMs         = [Math]::Round($totalCpuKernelMs, 2)
        CpuTotalMs          = [Math]::Round($totalCpuUserMs + $totalCpuKernelMs, 2)
        TotalThreads        = $totalThreads
        TotalHandles        = $totalHandles
    }
}

function Get-ProcessIoSnapshot {
    param([System.Diagnostics.Process]$Process)
    $res = [PSCustomObject]@{
        BytesRead        = [long]0
        BytesWritten     = [long]0
        ReadOperations   = [long]0
        WriteOperations  = [long]0
    }
    if (-not $Process) { return $res }

    try {
        if (-not $Process.HasExited) {
            $io = New-Object TomwareCollector.NativeMethods+IO_COUNTERS
            $ok = [TomwareCollector.NativeMethods]::GetProcessIoCounters($Process.Handle, [ref]$io)
            if ($ok) {
                $res.BytesRead = [long]$io.ReadTransferCount
                $res.BytesWritten = [long]$io.WriteTransferCount
                $res.ReadOperations = [long]$io.ReadOperationCount
                $res.WriteOperations = [long]$io.WriteOperationCount
            }
        }
    } catch {}
    return $res
}

function Get-LoadedModulesSafe {
    param([System.Diagnostics.Process]$Process)
    $modules = @()
    if (-not $Process) { return $modules }

    try {
        if (-not $Process.HasExited) {
            foreach ($mod in $Process.Modules) {
                try {
                    $modPath = $mod.FileName
                    $sha = $null
                    if (Test-Path $modPath) {
                        $sha = (Get-FileHash -Path $modPath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
                    }
                    $modules += [PSCustomObject]@{
                        name         = $mod.ModuleName
                        path         = $modPath
                        base_address = "0x{0:X}" -f $mod.BaseAddress.ToInt64()
                        sha256       = if ($sha) { $sha.ToLower() } else { $null }
                    }
                } catch {}
            }
        }
    } catch {}
    return $modules
}

function Stop-ProcessTreeGuaranteed {
    param(
        [int]$RootPid = 0,
        [string]$SamplePath = ""
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        if ($RootPid -gt 0) {
            cmd.exe /c "taskkill /PID $RootPid /T /F >nul 2>&1" | Out-Null
            Start-Sleep -Milliseconds 100
            try {
                $p = Get-Process -Id $RootPid -ErrorAction SilentlyContinue
                if ($p -and -not $p.HasExited) { $p.Kill() }
            } catch {}
        }

        if ($SamplePath) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($SamplePath)
            if ($base) {
                cmd.exe /c "taskkill /IM `"$base.exe`" /T /F >nul 2>&1" | Out-Null
            }
        }

        cmd.exe /c "taskkill /IM pin.exe /T /F >nul 2>&1" | Out-Null
        cmd.exe /c "taskkill /IM pinbin.exe /T /F >nul 2>&1" | Out-Null
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Join-ProcessArguments {
    param([string[]]$ArgumentList)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($a in @($ArgumentList)) {
        if ($null -eq $a -or $a -eq "") { continue }
        if ($a -match '[\s"]') {
            $parts.Add(('"{0}"' -f ($a -replace '"', '\"')))
        } else {
            $parts.Add([string]$a)
        }
    }
    return ($parts -join " ")
}

function Start-ObservedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory = "",
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][string]$StderrPath
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = Join-ProcessArguments -ArgumentList $ArgumentList
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $outFs = [System.IO.File]::Open($StdoutPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $errFs = [System.IO.File]::Open($StderrPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $outCopy = $proc.StandardOutput.BaseStream.CopyToAsync($outFs)
    $errCopy = $proc.StandardError.BaseStream.CopyToAsync($errFs)
    return [PSCustomObject]@{
        Process = $proc
        StdoutStream = $outFs
        StderrStream = $errFs
        StdoutCopy = $outCopy
        StderrCopy = $errCopy
    }
}

function Complete-ObservedProcess {
    param($Observed, [int]$WaitMs = 3000)
    if ($null -eq $Observed) { return $null }
    $proc = $Observed.Process
    if ($proc -and -not $proc.HasExited) {
        [void]$proc.WaitForExit($WaitMs)
    }
    try { if ($Observed.StdoutCopy) { [void]$Observed.StdoutCopy.Wait(2000) } } catch {}
    try { if ($Observed.StderrCopy) { [void]$Observed.StderrCopy.Wait(2000) } } catch {}
    foreach ($s in @($Observed.StdoutStream, $Observed.StderrStream)) {
        if ($s) { try { $s.Flush(); $s.Dispose() } catch {} }
    }
    if ($proc) {
        try {
            if ($proc.HasExited) {
                $proc.WaitForExit()
                return $proc.ExitCode
            }
        } catch {
            return $null
        }
    }
    return $null
}
