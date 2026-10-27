subject_id: BEN_07
sha256: 0528568f4ead8fc3ac7eeac119eab8de7186fdfafe67adab8f610478b9a6b54a
observed_sha256: 0528568F4EAD8FC3AC7EEAC119EAB8DE7186FDFAFE67ADAB8F610478B9A6B54A
pe_path: C:\TOMWare\samples\benign\0528568f4ead8fc3ac7eeac119eab8de7186fdfafe67adab8f610478b9a6b54a.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_07\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!IsDebuggerPresent; VCRUNTIME140.dll!memcmp
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0; memcmp ascii=1 utf16=0
