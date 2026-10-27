subject_id: BEN_11
sha256: 0706893c0c4262ecb4d8bfa38f1a90ebd0b6f61d332319e124f56f98c7317231
observed_sha256: 0706893C0C4262ECB4D8BFA38F1A90EBD0B6F61D332319E124F56F98C7317231
pe_path: C:\TOMWare\samples\benign\0706893c0c4262ecb4d8bfa38f1a90ebd0b6f61d332319e124f56f98c7317231.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_11\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!QueryPerformanceCounter
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0
