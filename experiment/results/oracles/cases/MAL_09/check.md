subject_id: MAL_09
sha256: 1979b3e9366928d0774a41e8bd5e7610a0302cdf62e9a533d2ff6c5ff7c346e9
observed_sha256: 1979B3E9366928D0774A41E8BD5E7610A0302CDF62E9A533D2FF6C5FF7C346E9
pe_path: C:\TOMWare\malwares\infected\1979b3e9366928d0774a41e8bd5e7610a0302cdf62e9a533d2ff6c5ff7c346e9.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_09\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!QueryPerformanceCounter
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0
