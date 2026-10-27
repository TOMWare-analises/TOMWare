subject_id: BEN_15
sha256: 07976cd85c285b58015867aa84cbe0611c7c801d9be0232b03cda3b886c5c331
observed_sha256: 07976CD85C285B58015867AA84CBE0611C7C801D9BE0232B03CDA3B886C5C331
pe_path: C:\TOMWare\samples\benign\07976cd85c285b58015867aa84cbe0611c7c801d9be0232b03cda3b886c5c331.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_15\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!GetModuleHandleExW
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; QueryPerformanceFrequency ascii=1 utf16=0; GetModuleHandle ascii=2 utf16=0
