subject_id: MAL_02
sha256: 02ab409a3fa69005878bcd00d41f32330073e5606d60b7635fd970e92acdead0
observed_sha256: 02AB409A3FA69005878BCD00D41F32330073E5606D60B7635FD970E92ACDEAD0
pe_path: C:\TOMWare\malwares\infected\02ab409a3fa69005878bcd00d41f32330073e5606d60b7635fd970e92acdead0.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_02\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!GetModuleHandleExW
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; WaitForSingleObject ascii=1 utf16=0; GetModuleHandle ascii=2 utf16=0
