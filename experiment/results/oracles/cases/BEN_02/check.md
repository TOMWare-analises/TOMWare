subject_id: BEN_02
sha256: 01a604553bc43d44a39f7ed7e910f3485c5805af65036c1aadf027ef5d2d5158
observed_sha256: 01A604553BC43D44A39F7ED7E910F3485C5805AF65036C1AADF027EF5D2D5158
pe_path: C:\TOMWare\samples\benign\01a604553bc43d44a39f7ed7e910f3485c5805af65036c1aadf027ef5d2d5158.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_02\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!WaitForSingleObject; KERNEL32.dll!IsDebuggerPresent; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!GetModuleHandleW; KERNEL32.dll!OutputDebugStringW; KERNEL32.dll!WaitForSingleObjectEx; VCRUNTIME140.dll!memcmp
string_hits: IsDebuggerPresent ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; WaitForSingleObject ascii=3 utf16=0; GetModuleHandle ascii=1 utf16=0; memcmp ascii=1 utf16=0; OutputDebugString ascii=1 utf16=0
