subject_id: BEN_06
sha256: 0436f44255d26e463fe9554d30f5f681bec9aaec14fb8ef53acbdea838b1f39d
observed_sha256: 0436F44255D26E463FE9554D30F5F681BEC9AAEC14FB8EF53ACBDEA838B1F39D
pe_path: C:\TOMWare\samples\benign\0436f44255d26e463fe9554d30f5f681bec9aaec14fb8ef53acbdea838b1f39d.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_06\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetTickCount64; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!OutputDebugStringW; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!WaitForSingleObjectEx; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!GetModuleHandleExW; KERNEL32.dll!SleepEx
string_hits: IsDebuggerPresent ascii=1 utf16=0; NtQuerySystemInformation ascii=2 utf16=0; GetTickCount ascii=1 utf16=0; GetTickCount64 ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; QueryPerformanceFrequency ascii=1 utf16=0; SleepEx ascii=1 utf16=0; WaitForSingleObject ascii=2 utf16=0; GetModuleHandle ascii=2 utf16=0; OutputDebugString ascii=2 utf16=0
