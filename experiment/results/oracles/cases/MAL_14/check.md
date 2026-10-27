subject_id: MAL_14
sha256: 308af6a404d8a91387ddab482a38fdf266e5f903d0e7ff4cac59ebc137ec288c
observed_sha256: 308AF6A404D8A91387DDAB482A38FDF266E5F903D0E7FF4CAC59EBC137EC288C
pe_path: C:\TOMWare\malwares\infected\308af6a404d8a91387ddab482a38fdf266e5f903d0e7ff4cac59ebc137ec288c.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\MAL_14\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!GetModuleHandleExW; KERNEL32.dll!WaitForSingleObject; ntdll.dll!NtQuerySystemInformation
string_hits: IsDebuggerPresent ascii=1 utf16=0; NtQuerySystemInformation ascii=2 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; WaitForSingleObject ascii=1 utf16=0; GetModuleHandle ascii=2 utf16=0
