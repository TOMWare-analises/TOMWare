# Item-by-item verification against the English article (CFD80)

Base: `Mitigating_…REVISION (1)(1).pdf`, SHA-256 prefix `CFD80F0D0EE9` (full digest in `SHA256SUMS.txt`), 22 pages, English. Older pack file `Access-2026-38745_CURRENT.pdf` (`5CBC8E96…`) is withdrawn.

After the seven actions, no further documentary correction identified here remains. Experimental limitations in item 6 stay open.

| # | Action | Status in CFD80 *before* this revision | Status *after* Tables 21–27 + letter | Remaining |
|---|---|---|---|---|
| 1 | Use latest English PDF; retire Portuguese-excerpt instructions | Pack still copied CURRENT `5CBC`; `OVERLEAF_PARA_O_AMIGO.md` and `PATCH_VB_VIC_VIIA_EN.md` still talked about Portuguese pages. CFD80 itself is already English. | Base = CFD80. CURRENT 5CBC not in the pack. Instructions point to English V-B/VI-C/VII-A denials, not Portuguese excerpts. | Overleaf still holds the unpublished `.tex`. |
| 2a | Module32 positive control in `.tex` | V-B (extract ~778–790): complementary TestModule32 already negative in baseline; “do not include specific positive controls for Module32*”. VI-C (~1534–1536) and VII-A (~1637–1639) repeat the denial. Table 6 is process `pin.exe` only. | Table 21 + replacement paragraphs. Denials deleted. | Fixture is dummy `pinvm.dll`, not real Pin; `NtQuerySystemInformation` / full `GetModuleHandle` matrix still unvalidated (declared). |
| 2b | Combined `-da`, one run per oracle | CFD80 has TMW_ALL in Table 19. No oracle smoke-test table. Filename `da_n10.csv` was easy to misread as N=10. | Table 22: five rows, campaign id `t2_n10_v7b`. | Smoke test ≠ corpus interaction study. |
| 2c | memcmp / `_memicmp` / `RtlCompareMemory` | V-D (~1126): “restricted to the memcmp comparisons exercised by the oracle.” Table 12 only. | Table 23. Pass-through OK. Unexercised exports named. | Named exports remain unimplemented as individual controls. |
| 2d | `_memicmp_l` fault | Not in CFD80. | Stated: FOUND; NAT/TMW0 PASS; `-dm`/`-da` MASKED then ACCESS_FAULT; DLL `D55EC952` does not revalidate 9,000. | Campaign DLL keeps the 3-arg hook. |
| 2e | 22/30 full diagnostic in Results | Introduction ~139–146 only. No table of the eight disagreements. | Table 24 in Section VI. Method, 10 PE, 3 reps, criterion, 8 disagreements. | Not API equivalence (declared). |
| 2f | R4.3 BEN_28 / 46 / 47 | Not in CFD80. Table 16/19 is the 1,000+1,000 corpus contrast. | Table 25. `identified=false`. Persistence ≠ progress. | N=1 diagnostic. |
| 2g | 6,517 unavailable exit codes | VI-D already relabels `crash_exit`. Counts appear as “No exit code” in Table 19 but the 6,517 total and PowerShell null-ExitCode mechanism are not fully written. | Paragraph in VI-D: 6,517 rows; true coded crash = 0; JSON not rewritten; collector v2.1 prospective. | Original 9,000 JSON unchanged. |
| 2h | Corpus manifesto path and limits | Table 18 composition only. Path `corpus.csv` and coarse-label limits incomplete. | Path, columns, `Trojan_Bazaar`/`Backdoor_Bazaar`, packer unknown, `targeted_evasion=unverified`. | No VirusTotal families. |
| 3a | NAT / EMPTY / TMW0 baseline numbers | Conditions named in VI-B and Table 19. No table of 0.260 / 1.485 / 1.973 s. | Table 26, n=25 short-lived benign. Two contrasts stated. | Incremental tables remain TMW0 versus module (Table 20). |
| 3b | Pin without Pintool: real stdout/stderr/exit | VI-B: “unsuccessful preliminary check”; protocol only. | Table 27: exit 0, empty stderr, oracle stdout; campaign still omitted PIN. | 9,000 have no PIN cells. |
| 4a | Letter: 2,000 attempts not 9,000 TMW0 vs TMW_DO | Prior letter said “9,000 TMW0 versus TMW_DO”. | 1,000 + 1,000 = 2,000. | — |
| 4b | 98 duration pairs; 97 CPU/memory SanitizePinEnvVars | CFD80 Methods already has this (~1600–1605). | Letter repeats 98 / 97 (BEN_32). | — |
| 4c | Formal R5.4 citing recent refs already in the paper | Prior letter: “Optional. No unread citations added.” | R5.4 cites [6] Park 2024, [15] Padhy 2025, [18] Gaber Peekaboo 2025, [19] Norby 2025, [21] Zhao LibIHT 2025, plus [9],[10]. | Citation ≠ bake-off. |
| 4d | Inconsistent captures → tables | CFD80 is already table-based; prior pack still referred to screenshot panels. | Letter states captures removed or replaced by Tables 3, 6, 12, 21–27. | — |
| 4e | Hook counters per binary not collected | CFD80 VII-B: internal counters disabled. | Letter states they were not collected in the 9,000. | Item 6. |
| 4f | Exact section/table numbers | Prior letter used vague “Same as”. | Each reply names V-A/B/D/E, VI-B/C/D/E, VII-A/B, VIII, Tables 1, 3, 6, 12, 15–27. | — |
| 4g | No “Same as R1.1” | Prior `CARTA_PONTO_A_PONTO_EN.md` used it. | `CARTA_FINAL_EN.md` repeats the full answer for each reviewer. | Old letter file withdrawn from the pack. |
| 4h | Do not claim a baseline ladder table before inserting it | CFD80 had no Table 26. | Table 26 is inserted; the letter cites it only after that insertion. | — |
| 5 | Single reproducibility commit | Pack cited `e382a6c`; `REPRODUCIBILITY.txt` cited `58ea738`; stamp `cf735e1`. | One landing commit, stamped in article notes, manifesto, letter, instructions, pack `MANIFEST.json`. | Push remains the authors’ action. |
| 6 | Keep partial if no new experiments | CFD80 already concedes traces/coverage, counters off, temporal coherence, no malware chain, no Arancino experiment. | Letter header and VII-D/VIII keep all five as open. No new VM runs. | These five stay open. |
| 7 | Full HL article, full clean article, final letter, retire old matrices | Pack had insert PDFs + CURRENT 5CBC + `MATRIZ_SEIS_REVISORES.csv` + `RELATORIO_SEIS_REVISORES.md`. | Merged CFD80 + Tables 21–27 (HL and clean); letter PDF from `CARTA_FINAL_EN.md`; matrices and CURRENT withdrawn. | IEEE two-column `.tex` remains on Overleaf; this repo supplies `Access-2026-38745_REVISION_TABLES.tex`. |

English CFD80 sentences that this revision deletes (verbatim sense):

1. V-B: no specific positive controls for Module32* or GetModuleHandleA/W.
2. V-D: functional evidence restricted to memcmp.
3. VI-C: absence of monitored modules in the baseline is not a positive control.
4. VII-A: absence of target modules prevents confirmation of Module32 filtering.

English CFD80 sentences that this revision keeps (already correct):

- Abstract: no 155/155, no 9/31, no −87.2%; 11/30 to 30/30; 9.6% to 52.8% / 32.8% to 57.6%; no equivalence.
- Table 3 matched AntiDebug; Table 15 N=30; Table 19 nine conditions; 98 duration pairs; SanitizePinEnvVars 97 CPU/memory; post hoc resource filter; no Arancino experiment.
