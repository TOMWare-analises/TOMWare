# Technical items 1–9 (Access only)

| # | Task | Status | Evidence |
|---|---|---|---|
| 1 | Pin without Pintool | **Recorded.** Guest 22 Oct: exit 0, oracle OK, PIN omitted from 9,000. Host 30 Oct: StartServer assertion, 718 ms, `not_supported_by_engine`, oracle SHA-256 `3B25069E…`, pin.exe SHA-256 `FBA632E4…` (not the guest campaign binary). | `pin_probe.csv`; `pin_bare_probe_host/` |
| 2 | R4.3 process tree | **Script fixed; 9 guest runs not yet executed.** `$pid` → `$procId`. New campaign `access_r43b_process_tree`. Old `access_r43` preserved. VM `Windows 10 x64-tomware` was powered on; guest login was not available from this host session. | `Run-AccessR43b.ps1`; `PASSO_A_PASSO_ACCESS_R43B.txt` |
| 3 | NAT/EMPTY/TMW0 table | **Done.** Benign short-lived n=25: 0.260 / 1.485 / 1.973 s. Paired deltas and missing CPU/WS counts included. | `nat_empty_tmw0_table.csv` |
| 4 | Single reproducible commit | Landing commit of this drop (stamped in `REPRODUCIBILITY.txt`). Supersedes `e382a6c` / `58ea738` / `53a7ee0` as the citation. | `REPRODUCIBILITY.txt` |
| 5 | Evidence pack | This zip. CURRENT 5CBC and old matrices remain withdrawn. JCVHT stays out. | `SHA256SUMS.txt` |
| 6 | Temporal coherence | **Not run.** Guest protocol only. Keep as partial. | `PASSO_A_PASSO_ACCESS_ITENS_6_9.txt` |
| 7 | Interface matrix + 4-arg `_memicmp_l` | **Not run on a new DLL.** Source already has `wMemcmpIL` (4 args). A new hash is required; it cannot revalidate the 9,000. Keep as partial. | same |
| 8 | Paired behavioural evidence | **Not run.** `-mc` was off in the 9,000. Keep as partial. | same |
| 9 | Real evasive case | **Not run.** `identified=false`. Gate remains `Run-M3-CaseStudy.ps1`. Keep as partial. | same |

Do not mix JCVHT 31/3,100/10 s cells.
