subject_id: BEN_12
sha256: 070a98b4f7c03f99048a10f490d5916a9a98417e0d0de2c414c76b3dd00cb35e
observed_sha256: 070A98B4F7C03F99048A10F490D5916A9A98417E0D0DE2C414C76B3DD00CB35E
pe_path: C:\TOMWare\samples\benign\070a98b4f7c03f99048a10f490d5916a9a98417e0d0de2c414c76b3dd00cb35e.exe
api_or_rva:
extract_path: C:\TOMWare\jcvht_identify\cases\BEN_12\imports.txt
identified: false
why_not_just_counter: string or IAT hit is a lead, not a case study. identified stays false until a human cites API or RVA and an extract.
comment_ids: M3, M2
scan_status: scanned
iat_hits: KERNEL32.dll!GetTickCount; KERNEL32.dll!QueryPerformanceCounter; KERNEL32.dll!GetModuleHandleW
string_hits: GetTickCount ascii=1 utf16=0; QueryPerformanceCounter ascii=1 utf16=0; GetModuleHandle ascii=1 utf16=0
