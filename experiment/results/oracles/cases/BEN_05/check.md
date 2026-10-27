subject_id: BEN_05
sha256: 0244aa8269c39e74663920ca738fec27bde0a1bb6667feb24299903864337f12
observed_sha256: 0244AA8269C39E74663920CA738FEC27BDE0A1BB6667FEB24299903864337F12
pe_path: C:\TOMWare\samples\benign\0244aa8269c39e74663920ca738fec27bde0a1bb6667feb24299903864337f12.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_05\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetTickCount; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!GetModuleHandleW
string_hits: GetTickCount ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0
