subject_id: BEN_14
sha256: 0785c9b642c2b7fc0a09d9df0fd90c9cd6766fcb1cfcc0b08d194bb28e31a030
observed_sha256: 0785C9B642C2B7FC0A09D9DF0FD90C9CD6766FCB1CFCC0B08D194BB28E31A030
pe_path: C:\TOMWare\samples\benign\0785c9b642c2b7fc0a09d9df0fd90c9cd6766fcb1cfcc0b08d194bb28e31a030.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_14\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!GetTickCount
string_hits: GetTickCount ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0
