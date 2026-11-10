# Inventory — existing evidence / minimum action / expected output

Frozen at 2026-10-22T17:20:41Z.
Catalog of the 9000 JSON: `raw_runs_sha256.csv` (merkle `382f98e25fb46e95f168f7df0283175ebd067835d5760c10f60c2c12f14398ae`).
Campaign DLL = host DLL: `4bbc62707ee0b2ef922d4e8659a6392d92814ea0fc74f4682f1187562ae7f0e6`.
EmptyPinTool: `804be19bf7924b641fe25f07ea89dec26dc9daa36c49638f407ff96e2ab153c8`.
Pin: 3.28.98749. Seed: 705851366.

| ID | Existing evidence | Minimum action | Expected output | Status |
|---|---|---|---|---|
| E0 | Overleaf PDF = 13/10 revision (hash `0FEF4163...`) | Do not edit the PDF now; at the end a single instructions PDF | Overleaf only changes after the VM stages + final values | done |
| E1 | Protocol, config, scripts, corpus, C++ sources, 9000 JSON | SHA-256 hash, do not alter raw files | `frozen_manifest.csv` | done |
| E2 | 9000 JSON; 6517 `exception_crash` with null `exit_code` | Reclassify without overwriting | `02_audit/*` | done |
| E3 | `Invoke-SingleRun.ps1` and `Run-MatchedOracles.ps1` lose ExitCode | Fix capture; NAT test with exits 0, 1 and exception | protocol v2; old campaign is not reprocessed with v2 | pending |
| E4a | AntiDebug: 1 run per condition in the 21/10 CSV | 3 repetitions NAT / TMW0 / TMW `-dd` with `-gdb` | CSV 3+3 | VM |
| E4b | Timing N=30 (90 rows) | Keep; record provenance | hash `76208218...` already in the manifest | done (do not repeat) |
| E4c | Pin probe without `-t` (`pin_condition_valid=false`) | Record output and reason | block note | VM or existing log |
| E4d | `-da` on the 5 oracles: PE_da and DA_overhead exist; AD/EV/MS incomplete | Complete `-da` on the 5 | CSV | VM |
| E4e | TestConcurrentWaits / Module32: native OK; Pin timeout -2 | Positive control EmptyPin + declared timeout | CSV | VM |
| E5 | `ModuleCounters.cpp` and knobs `-mc`/`-mcf` in the code; `module_counters.enabled=false` | 600 diagnostic runs TMW0_COUNT / TMW_ALL_COUNT | `module_events_by_run.csv` | VM |
| E6 | `FidelityProbe` is another pintool | External observation (ProcMon/ETW), 120 runs | fidelity dossier | VM; needs coauthor OK |
| E7 | Exit codes of the 9000 are not recoverable | 1800 runs with collector v2 | prospective confirmation | VM |
| E8 | Arancino absent from the repo | Check Pin 2.x / x86 vs Pin 3.28 x64 | bake-off or documented block | **blocked** 23/10; `08_arancino/BLOQUEIO.md` |
| E9 | `corpus.csv` has SHA-256, group, profile; generic family | Metadata only from PE header / verifiable source | `MANUSCRIPT_VALUES.json` | **OK** 23/10; `09_values/` |
| E10 | Current EN/PT letters have errors | Regenerate only at the end | single Overleaf PDF + letters | end |

## Numbers already audited (use these, not those in the PDF)

Outcomes (n=250 per cell):

- Benign persistent, window survival: NAT 8.0% [5.2, 12.0]; EMPTY 11.2%; TMW0 9.6%; TMW_DO 52.8% [46.6, 58.9]; TMW_ALL 56.4% [50.2, 62.4].
- Malicious persistent: NAT 54.4% [48.2, 60.5]; EMPTY 32.4%; TMW0 32.8%; TMW_DO 57.6%; TMW_ALL 64.0% [57.9, 69.7].
- `natural_exit` = 0. True `exception_crash` = 0. The 6517 are termination before the limit with unknown code.
- NAT benign short: only 2 of 25 binaries have resources (`n_pairs_ws=2` in the EMPTY-NAT contrast). Do not publish that cell as n=25.
- TMW_DM − TMW0, short malicious, WS: +0.451 MB [0.049, 0.805], n_pairs=25. CI does not include zero.

Timing N=30 (conventional medians): TMW0 2433.285; GO 3083.210 (11/30 below); GO_DO 2104.770 (30/30). Wilson 11/30 = 21.87–54.49%; 30/30 = 88.65–100%.
