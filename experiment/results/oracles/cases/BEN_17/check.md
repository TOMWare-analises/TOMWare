subject_id: BEN_17
sha256: 096473a4a449d224ac737fd6bb0f326c0aa7f6d713c57f6a728a1bd362671ebc
observed_sha256: 096473A4A449D224AC737FD6BB0F326C0AA7F6D713C57F6A728A1BD362671EBC
pe_path: C:\TOMWare\samples\benign\096473a4a449d224ac737fd6bb0f326c0aa7f6d713c57f6a728a1bd362671ebc.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_17\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetModuleHandleA; KERNEL32.dll!GetModuleHandleExW; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!GetTickCount; KERNEL32.dll!GetTickCount64; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!OutputDebugStringA; KERNEL32.dll!OutputDebugStringW; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!RegisterWaitForSingleObject
string_hits: IsDebuggerPresent ascii=1 utf16=0; NtQueryInformationProcess ascii=1 utf16=0; NtQuerySystemInformation ascii=1 utf16=0; GetTickCount ascii=3 utf16=0; GetTickCount64 ascii=1 utf16=0; QueryPerformanceCounter ascii=2 utf16=0; QueryPerformanceFrequency ascii=2 utf16=0; WaitForSingleObject ascii=6 utf16=0; CreateToolhelp32Snapshot ascii=1 utf16=0; Module32First ascii=2 utf16=0; Module32Next ascii=2 utf16=0; GetModuleHandle ascii=4 utf16=0; memcmp ascii=1 utf16=0; OutputDebugString ascii=4 utf16=0; PIN_ ascii=2 utf16=0
