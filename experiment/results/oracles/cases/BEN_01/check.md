subject_id: BEN_01
sha256: 005d8b80ed17c1b374ad8d4dd121cd240506da55cae4977a8b9eae42436034a3
observed_sha256: 005D8B80ED17C1B374AD8D4DD121CD240506DA55CAE4977A8B9EAE42436034A3
pe_path: C:\TOMWare\samples\benign\005d8b80ed17c1b374ad8d4dd121cd240506da55cae4977a8b9eae42436034a3.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_01\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: api-ms-win-crt-private-l1-1-0.dll!memcmp; api-ms-win-core-libraryloader-l1-2-0.dll!GetModuleHandleExW; api-ms-win-core-libraryloader-l1-2-0.dll!GetModuleHandleW; api-ms-win-core-synch-l1-1-0.dll!WaitForSingleObject; api-ms-win-core-synch-l1-1-0.dll!WaitForSingleObjectEx; api-ms-win-core-debug-l1-1-0.dll!OutputDebugStringA; api-ms-win-core-debug-l1-1-0.dll!IsDebuggerPresent; api-ms-win-core-debug-l1-1-0.dll!OutputDebugStringW; api-ms-win-core-sysinfo-l1-1-0.dll!GetTickCount; api-ms-win-core-profile-l1-1-0.dll!QueryPerformanceCounter
string_hits: IsDebuggerPresent ascii=1 utf16=0; GetTickCount ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; WaitForSingleObject ascii=2 utf16=0; GetModuleHandle ascii=2 utf16=0; memcmp ascii=1 utf16=0; OutputDebugString ascii=2 utf16=0
