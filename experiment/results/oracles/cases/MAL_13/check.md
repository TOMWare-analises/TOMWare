subject_id: MAL_13
sha256: 2a2b6b75359f4b74de136bc2c3c3a31633d3fcc169f2e2789e4d3f776ebb9e24
observed_sha256: 2A2B6B75359F4B74DE136BC2C3C3A31633D3FCC169F2E2789E4D3F776EBB9E24
pe_path: C:\TOMWare\malwares\infected\2a2b6b75359f4b74de136bc2c3c3a31633d3fcc169f2e2789e4d3f776ebb9e24.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_13\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!WaitForSingleObjectEx; KERNEL32.dll!GetModuleHandleExW; KERNEL32.dll!OutputDebugStringW; KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!GetModuleHandleA; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!CreateToolhelp32Snapshot; KERNEL32.dll!Process32First; KERNEL32.dll!Process32Next; KERNEL32.dll!RegisterWaitForSingleObject; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!OutputDebugStringA; KERNEL32.dll!GetTickCount
string_hits: IsDebuggerPresent ascii=1 utf16=0; NtQueryInformationProcess ascii=1 utf16=0; NtQuerySystemInformation ascii=1 utf16=0; GetTickCount ascii=2 utf16=0; GetTickCount64 ascii=1 utf16=0; QueryPerformanceCounter ascii=2 utf16=0; QueryPerformanceFrequency ascii=2 utf16=0; WaitForSingleObject ascii=5 utf16=0; CreateToolhelp32Snapshot ascii=2 utf16=0; Process32First ascii=1 utf16=0; Process32Next ascii=1 utf16=0; Module32First ascii=2 utf16=0; Module32Next ascii=2 utf16=0; GetModuleHandle ascii=4 utf16=0; memcmp ascii=2 utf16=0; OutputDebugString ascii=2 utf16=0
