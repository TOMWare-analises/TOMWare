subject_id: MAL_07
sha256: 153e11471f85de3df5135b0445014698333ff40a9d6c488d291d6517eb19800d
observed_sha256: 153E11471F85DE3DF5135B0445014698333FF40A9D6C488D291D6517EB19800D
pe_path: C:\TOMWare\malwares\infected\153e11471f85de3df5135b0445014698333ff40a9d6c488d291d6517eb19800d.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_07\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetModuleHandleA; KERNEL32.dll!GetTickCount64; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!WaitForSingleObjectEx; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!GetModuleHandleExW; KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!SleepEx
string_hits: IsDebuggerPresent ascii=1 utf16=0; NtQuerySystemInformation ascii=2 utf16=0; GetTickCount ascii=1 utf16=0; GetTickCount64 ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; QueryPerformanceFrequency ascii=1 utf16=0; SleepEx ascii=1 utf16=0; WaitForSingleObject ascii=2 utf16=0; GetModuleHandle ascii=4 utf16=0
