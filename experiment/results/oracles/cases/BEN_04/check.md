subject_id: BEN_04
sha256: 02157472592f01a01af87d5495d2520993ebcc7f2f3d39cfb1a88f2a991a573a
observed_sha256: 02157472592F01A01AF87D5495D2520993EBCC7F2F3D39CFB1A88F2A991A573A
pe_path: C:\TOMWare\samples\benign\02157472592f01a01af87d5495d2520993ebcc7f2f3d39cfb1a88f2a991a573a.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_04\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!SleepEx; KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!QueryPerformanceFrequency; KERNEL32.dll!QueryPerformanceCounter; VCRUNTIME140.dll!memcmp
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; QueryPerformanceFrequency ascii=1 utf16=0; SleepEx ascii=1 utf16=0; WaitForSingleObject ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0; memcmp ascii=1 utf16=0
