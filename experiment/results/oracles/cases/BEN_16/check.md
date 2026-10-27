subject_id: BEN_16
sha256: 07c1f3b3ddc138d037acad8ee6eaa54488b4918861bdaff3fc4ae9796ae79d1c
observed_sha256: 07C1F3B3DDC138D037ACAD8EE6EAA54488B4918861BDAFF3FC4AE9796AE79D1C
pe_path: C:\TOMWare\samples\benign\07c1f3b3ddc138d037acad8ee6eaa54488b4918861bdaff3fc4ae9796ae79d1c.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_16\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetTickCount; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!GetModuleHandleW
string_hits: GetTickCount ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0
