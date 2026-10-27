#Requires -Version 5.1
# Static IAT + string scan. Does NOT execute any PE.
# Does NOT set identified=true. A human must flip that after reading the extract.
# SkewMask/AntiDebug "fired" is not identification.
param(
    [string]$OutRoot = "C:\TOMWare\jcvht_identify",
    [switch]$All31
)
$ErrorActionPreference = "Continue"

$needles = @(
    "IsDebuggerPresent",
    "CheckRemoteDebuggerPresent",
    "NtQueryInformationProcess",
    "NtSetInformationThread",
    "NtQuerySystemInformation",
    "GetTickCount",
    "GetTickCount64",
    "QueryPerformanceCounter",
    "QueryPerformanceFrequency",
    "SleepEx",
    "NtDelayExecution",
    "WaitForSingleObject",
    "CreateToolhelp32Snapshot",
    "Process32First",
    "Process32Next",
    "Module32First",
    "Module32Next",
    "GetModuleHandle",
    "memcmp",
    "_memicmp",
    "RtlCompareMemory",
    "OutputDebugString",
    "FindWindow",
    "BeingDebugged",
    "NtGlobalFlag",
    "PIN_",
    "pin.exe",
    "pinvm",
    "pinipc"
)

$p0 = @(
    @{ id = "BEN_06"; sha = "0436f44255d26e463fe9554d30f5f681bec9aaec14fb8ef53acbdea838b1f39d" },
    @{ id = "MAL_07"; sha = "153e11471f85de3df5135b0445014698333ff40a9d6c488d291d6517eb19800d" },
    @{ id = "MAL_03"; sha = "04e4e646de39b18d7a9b4fe567dfdc986e21e469813f0069220649d26aed862d" },
    @{ id = "MAL_10"; sha = "1b5a4745d994e662ce897ae63f48f465cce8498c3605119ac9d8979318e43a71" }
)

$all31Path = Join-Path $PSScriptRoot "catalog_jcvht_31pe.csv"
$targets = @($p0)
if ($All31 -and (Test-Path $all31Path)) {
    $targets = Import-Csv $all31Path | ForEach-Object {
        @{ id = $_.sample_id; sha = $_.sha256 }
    }
}

$roots = @(
    "C:\TOMWare\samples\infected",
    "C:\TOMWare\samples\benign",
    "C:\TOMWare\malwares\infected",
    "C:\TOMWare\malwares\benign",
    "C:\TOMWare\corpus",
    "C:\TOMWare\experiment\corpus"
)

function Find-Pe([string]$sha) {
    foreach ($r in $roots) {
        $exe = Join-Path $r "$sha.exe"
        if (Test-Path $exe) { return $exe }
        $bare = Join-Path $r $sha
        if (Test-Path $bare) { return $bare }
    }
    foreach ($r in $roots) {
        $zip = Join-Path $r "$sha.zip"
        if (Test-Path $zip) { return $zip }
    }
    return $null
}

function Get-PeImports([string]$path) {
    $fs = [IO.File]::Open($path, "Open", "Read", "Read")
    try {
        $br = New-Object IO.BinaryReader $fs
        if ($br.ReadUInt16() -ne 0x5A4D) { return @("NOT_PE") }
        $fs.Seek(0x3C, "Begin") | Out-Null
        $e_lfanew = $br.ReadInt32()
        $fs.Seek($e_lfanew, "Begin") | Out-Null
        if ($br.ReadUInt32() -ne 0x00004550) { return @("BAD_PE") }
        $fs.Seek($e_lfanew + 24, "Begin") | Out-Null
        $magic = $br.ReadUInt16()
        $optOff = $e_lfanew + 24
        if ($magic -eq 0x20B) {
            $importRvaOff = $optOff + 112 + 8
            $numRvaOff = $optOff + 108
        } elseif ($magic -eq 0x10B) {
            $importRvaOff = $optOff + 96 + 8
            $numRvaOff = $optOff + 92
        } else { return @("UNKNOWN_MAGIC_$magic") }
        $fs.Seek($numRvaOff, "Begin") | Out-Null
        $numRva = $br.ReadUInt32()
        if ($numRva -lt 2) { return @("NO_IMPORT_DIR") }
        $fs.Seek($importRvaOff, "Begin") | Out-Null
        $impRva = $br.ReadUInt32()
        $impSize = $br.ReadUInt32()
        if ($impRva -eq 0) { return @("NO_IMPORTS") }

        $fs.Seek($e_lfanew + 6, "Begin") | Out-Null
        $nSec = $br.ReadUInt16()
        $fs.Seek($e_lfanew + 20, "Begin") | Out-Null
        $optSize = $br.ReadUInt16()
        $secOff = $e_lfanew + 24 + $optSize
        $secs = @()
        for ($i = 0; $i -lt $nSec; $i++) {
            $fs.Seek($secOff + $i * 40 + 8, "Begin") | Out-Null
            $vsz = $br.ReadUInt32()
            $vrva = $br.ReadUInt32()
            $rsz = $br.ReadUInt32()
            $rptr = $br.ReadUInt32()
            $secs += [pscustomobject]@{ vrva = $vrva; vsz = $vsz; rptr = $rptr; rsz = $rsz }
        }
        function RvaToOff([uint32]$rva) {
            foreach ($s in $secs) {
                if ($rva -ge $s.vrva -and $rva -lt ($s.vrva + [Math]::Max($s.vsz, $s.rsz))) {
                    return [int64]($s.rptr + ($rva - $s.vrva))
                }
            }
            return -1
        }
        function ReadAscii([int64]$off) {
            if ($off -lt 0) { return "" }
            $fs.Seek($off, "Begin") | Out-Null
            $bytes = New-Object System.Collections.Generic.List[byte]
            while ($bytes.Count -lt 260) {
                $b = $br.ReadByte()
                if ($b -eq 0) { break }
                $bytes.Add($b)
            }
            return [Text.Encoding]::ASCII.GetString($bytes.ToArray())
        }
        $impOff = RvaToOff $impRva
        if ($impOff -lt 0) { return @("IMPORT_RVA_UNMAPPED") }
        $out = New-Object System.Collections.Generic.List[string]
        $desc = 0
        while ($desc -lt 64) {
            $base = $impOff + $desc * 20
            $fs.Seek($base, "Begin") | Out-Null
            $ilt = $br.ReadUInt32()
            [void]$br.ReadUInt32()
            [void]$br.ReadUInt32()
            $nameRva = $br.ReadUInt32()
            $iat = $br.ReadUInt32()
            if ($ilt -eq 0 -and $nameRva -eq 0 -and $iat -eq 0) { break }
            $dll = ReadAscii (RvaToOff $nameRva)
            $thunkRva = if ($ilt -ne 0) { $ilt } else { $iat }
            $thunkOff = RvaToOff $thunkRva
            if ($thunkOff -ge 0) {
                for ($t = 0; $t -lt 256; $t++) {
                    $fs.Seek($thunkOff + $t * $(if ($magic -eq 0x20B) { 8 } else { 4 }), "Begin") | Out-Null
                    $val = if ($magic -eq 0x20B) { $br.ReadUInt64() } else { [uint64]$br.ReadUInt32() }
                    if ($val -eq 0) { break }
                    $ordinalBit = if ($magic -eq 0x20B) { 0x8000000000000000 } else { 0x80000000 }
                    if (($val -band $ordinalBit) -ne 0) {
                        $out.Add("$dll!#$( $val -band 0xFFFF )")
                    } else {
                        $hintOff = RvaToOff ([uint32]($val -band 0x7FFFFFFF))
                        $fn = ReadAscii ($hintOff + 2)
                        if ($fn) { $out.Add("$dll!$fn") }
                    }
                }
            }
            $desc++
        }
        if ($out.Count -eq 0) { return @("IMPORTS_EMPTY_OR_PACKED") }
        return $out
    } catch {
        return @("PARSE_ERROR:$($_.Exception.Message)")
    } finally {
        $fs.Close()
    }
}

function Get-StringHits([string]$path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $ascii = [Text.Encoding]::ASCII.GetString($bytes)
    $utf16 = [Text.Encoding]::Unicode.GetString($bytes)
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($n in $needles) {
        $a = ([regex]::Matches($ascii, [regex]::Escape($n))).Count
        $u = ([regex]::Matches($utf16, [regex]::Escape($n))).Count
        if ($a -gt 0 -or $u -gt 0) {
            $hits.Add("$n ascii=$a utf16=$u")
        }
    }
    return $hits
}

New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null
$summary = New-Object System.Collections.Generic.List[object]

foreach ($t in $targets) {
    $id = $t.id
    $sha = $t.sha
    $caseDir = Join-Path $OutRoot "cases\$id"
    New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
    $pe = Find-Pe $sha
    $status = "missing"
    $imports = @()
    $strHits = @()
    $importHits = @()
    $size = 0
    $peHash = ""
    if ($pe) {
        if ($pe.ToLower().EndsWith(".zip")) {
            $status = "zip_only_not_extracted"
        } else {
            $status = "scanned"
            $size = (Get-Item $pe).Length
            $peHash = (Get-FileHash $pe -Algorithm SHA256).Hash
            $imports = @(Get-PeImports $pe)
            $strHits = @(Get-StringHits $pe)
            $importHits = @($imports | Where-Object {
                $line = $_
                $needles | Where-Object { $line -like "*${_}*" }
            })
            $imports | Set-Content (Join-Path $caseDir "imports.txt") -Encoding ASCII
            $strHits | Set-Content (Join-Path $caseDir "string_hits.txt") -Encoding ASCII
        }
    }
    $why = "string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract."
    if ($status -eq "missing") { $why = "PE not found in known sample roots. Do not run T1." }
    if ($status -eq "zip_only_not_extracted") { $why = "found zip only; extract like campaign 9000, then re-run this script. Do not execute." }
    if ($imports -contains "NO_IMPORTS" -or $imports -contains "IMPORTS_EMPTY_OR_PACKED") {
        $why = "packed or no visible IAT. string hits alone do not identify a check."
    }
    $md = @"
subject_id: $id
sha256: $sha
observed_sha256: $peHash
pe_path: $pe
api_or_rva:
extract_path: $(Join-Path $caseDir "imports.txt")
identified: false
why_not_just_counter: $why
comment_ids: M3, M2
scan_status: $status
iat_hits: $($importHits -join "; ")
string_hits: $($strHits -join "; ")
"@
    Set-Content -Path (Join-Path $caseDir "check.md") -Value $md -Encoding ASCII
    $summary.Add([pscustomobject]@{
        sample_id = $id
        sha256 = $sha
        status = $status
        pe_path = $pe
        size_bytes = $size
        hash_match = ($(if ($peHash) { $peHash -ieq $sha } else { "" }))
        iat_hit_count = @($importHits).Count
        string_hit_count = @($strHits).Count
        iat_hits = ($importHits -join "|")
        string_hits = ($strHits -join "|")
        identified = "false"
    })
    Write-Host ("{0} {1} iat={2} str={3} {4}" -f $id, $status, @($importHits).Count, @($strHits).Count, $pe)
}

$sumCsv = Join-Path $OutRoot "identify_summary.csv"
$summary | Export-Csv -Path $sumCsv -NoTypeInformation -Encoding UTF8
Write-Host "wrote $sumCsv"
Write-Host "Do not run NAT/TMW0/knob. Bring identify_summary.csv and cases/*/check.md back to the host."
