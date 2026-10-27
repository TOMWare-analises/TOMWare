subject_id: MAL_08
sha256: 1693df9d970e011cf1c827fceaf49a3724f4478bc0ed7dc50f2d90ea417b6d38
observed_sha256: 1693DF9D970E011CF1C827FCEAF49A3724F4478BC0ED7DC50F2D90EA417B6D38
pe_path: C:\TOMWare\malwares\infected\1693df9d970e011cf1c827fceaf49a3724f4478bc0ed7dc50f2d90ea417b6d38.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_08\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetModuleHandleExW; KERNEL32.dll!OutputDebugStringW; KERNEL32.dll!WaitForSingleObjectEx; KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!GetModuleHandleA; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!GetTickCount64; KERNEL32.dll!CreateToolhelp32Snapshot; KERNEL32.dll!Process32First; KERNEL32.dll!Process32Next; KERNEL32.dll!RegisterWaitForSingleObject; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!OutputDebugStringA; KERNEL32.dll!GetTickCount
string_hits: IsDebuggerPresent ascii=1 utf16=0; NtQueryInformationProcess ascii=1 utf16=0; NtQuerySystemInformation ascii=1 utf16=0; GetTickCount ascii=3 utf16=0; GetTickCount64 ascii=2 utf16=0; QueryPerformanceCounter ascii=2 utf16=0; QueryPerformanceFrequency ascii=2 utf16=0; WaitForSingleObject ascii=5 utf16=0; CreateToolhelp32Snapshot ascii=2 utf16=0; Process32First ascii=1 utf16=0; Process32Next ascii=1 utf16=0; Module32First ascii=2 utf16=0; Module32Next ascii=2 utf16=0; GetModuleHandle ascii=4 utf16=0; memcmp ascii=1 utf16=3; OutputDebugString ascii=2 utf16=0
