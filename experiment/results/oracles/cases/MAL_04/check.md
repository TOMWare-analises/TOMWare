subject_id: MAL_04
sha256: 0cd6ef1c6fe1438ae173b70ded86ffbf634eaec341b788e23ae74e0e2f3323da
observed_sha256: 0CD6EF1C6FE1438AE173B70DED86FFBF634EAEC341B788E23AE74E0E2F3323DA
pe_path: C:\TOMWare\malwares\infected\0cd6ef1c6fe1438ae173b70ded86ffbf634eaec341b788e23ae74e0e2f3323da.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_04\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!GetModuleHandleExW; KERNEL32.dll!IsDebuggerPresent
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; QueryPerformanceFrequency ascii=1 utf16=0; WaitForSingleObject ascii=1 utf16=0; GetModuleHandle ascii=2 utf16=0
