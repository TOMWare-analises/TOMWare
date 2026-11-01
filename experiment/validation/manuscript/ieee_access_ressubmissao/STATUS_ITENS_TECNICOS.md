# Technical items 1–9 (Access only)

| # | Task | Status | Evidence |
|---|---|---|---|
| 1 | Pin without Pintool | **Guest N=3 ingested.** Launcher `920A730A`, 3/3 exit 0, stderr empty, oracle OK, 1900–2963 ms. Technically valid; omitted from the 9,000 by design. **Not incompatible.** Host StartServer withdrawn from Table 27. | `guest/pin_bare_guest_n3/` |
| 2 | R4.3 process tree | **r43d 27/27 ingested.** Launcher `pin\pin.exe` `920A730A`. Native 9/9 ENTRYPOINT; TMW0 9/9 EXITED 1.4–2.9 s; TMW_DO 9/9 STILL_ALIVE ~60.2 s. `behavioral_progress_observed=false`. r43c (FBA632E4 launcher) is not Table 25. | `access_r43d/summary.csv` |
| 3 | NAT/EMPTY/TMW0 table | **Done.** Benign short-lived n=25: 0.260 / 1.485 / 1.973 s. Paired deltas and missing CPU/WS counts included. | `nat_empty_tmw0_table.csv` |
| 4 | Single reproducible commit | **Public.** Cite `a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3` (HTTP 200, no auth). Supersedes `665aebba` (same tree; 404 on GitHub). Public `main` tip `86e3994c586a9c5306d204485e839cc91e1def70` is the citation stamp. | `commit_public_check.json` |
| 5 | Evidence pack | Collaborator zip `Access-2026-38745_ANALISE_AMIGO_2026-10-31` (article + letter + r43c extra). Not IEEE. JCVHT stays out. | `SHA256SUMS.txt` |
| 6 | Temporal coherence | **Not run.** Guest protocol only. Keep as partial. | `PASSO_A_PASSO_ACCESS_ITENS_6_9.txt` |
| 7 | Interface matrix + 4-arg `_memicmp_l` | **Not run on a new DLL.** Source already has `wMemcmpIL` (4 args). A new hash is required; it cannot revalidate the 9,000. Keep as partial. | same |
| 8 | Paired behavioural evidence | **Not run.** `-mc` was off in the 9,000. Keep as partial. | same |
| 9 | Real evasive case | **Not run.** `identified=false`. Gate remains `Run-M3-CaseStudy.ps1`. Keep as partial. | same |

Do not mix JCVHT 31/3,100/10 s cells.
