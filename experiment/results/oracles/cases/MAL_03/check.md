subject_id: MAL_03
sha256: 04e4e646de39b18d7a9b4fe567dfdc986e21e469813f0069220649d26aed862d
observed_sha256: 04E4E646DE39B18D7A9B4FE567DFDC986E21E469813F0069220649D26AED862D
pe_path: C:\TOMWare\malwares\infected\04e4e646de39b18d7a9b4fe567dfdc986e21e469813f0069220649d26aed862d.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_03\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetTickCount; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!GetModuleHandleA; KERNEL32.dll!SleepEx; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!WaitForSingleObjectEx; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!OutputDebugStringW; VCRUNTIME140.dll!memcmp
string_hits: IsDebuggerPresent ascii=1 utf16=0; GetTickCount ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; QueryPerformanceFrequency ascii=1 utf16=0; SleepEx ascii=1 utf16=0; WaitForSingleObject ascii=1 utf16=0; GetModuleHandle ascii=2 utf16=0; memcmp ascii=1 utf16=0; OutputDebugString ascii=1 utf16=0
