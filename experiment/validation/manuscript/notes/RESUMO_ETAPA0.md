# Stage 0 — Current article vs code and data

**PDF analyzed:** `Mitigating_...__REVISION_ (1).pdf` (Downloads, 22/10/2026 13:05)  
**SHA-256:** `0FEF4163C6153382AD94E350DAE742105AD9515C84C0D3C2BA03F84FA2AE5851`  
**Pages:** 23  

This file is **byte for byte the same** as `Mitigating_...__REVISION_.pdf` of 13/10 in the repository. Overleaf has not yet incorporated the 9,000-run campaign nor the N=30 timing.

Full table: `artigo_vs_codigo.csv` (38 claims).

## What is already consistent with the code (keep)

The tool description in the article matches the current C++:

- Five modules and knobs `-dd -dp -de -dm -do`; `-da` enables the five without `-go`.
- AntiDebug: only `BeingDebugged` and `NtGlobalFlag` via TEB/PEB; offsets 0xBC (x64) / 0x68 (x86); `-gdb` is registered **before** `-dd`.
- ProcessEnum: `Process32*` / `Module32*` / `GetModuleHandleA/W`; hides `pin.exe`, `pinvm.dll`, `pinipc.dll`, `TOMWare.dll`; does not touch `NtQuerySystemInformation`.
- SanitizePinEnvVars: PEB block before the CRT; `PIN_` → `ZZZ_` in place, same length.
- InstMemcmpMask: the 12 listed routines; second operand; exact length; default signatures `PIN_`, `pin.exe`, `pinvm.dll`, `pinipc.dll`.
- SkewMask: `Sleep` / `SleepEx` / `NtDelayExecution`; discount on QPC, `GetTickCount(64)`, `GetSystemTimePreciseAsFileTime`, `QueryInterruptTimePrecise`; no RDTSC.
- Timing oracle: `Sleep` 50 ms × 40 → threshold 3,000; pair `-go` vs `-go -do`.
- No experimental benchmark with Arancino / COBAI / Peekaboo.
- Compatibility ≠ behavioral equivalence; the article already says that.
- Corpus oracles do **not** prove that the malware used the 5 checks.

## What diverges and Overleaf must replace

The article still describes the **old** protocol. Current code and data are already another protocol.

| Article (this PDF) | Current code / data |
|---|---|
| 31 PE (17+14), 155 combinations, 3,100 launches | 100 PE (25+25+25+25), 9 conditions, 9,000 JSON |
| Persistent window 10 s | 60 s; short timeout 120 s |
| Baseline = Pin + TOMWare with module off | NAT / EMPTY / TMW0 ladder; Pin without `-t` is invalid |
| Modules only individual | TMW_ALL (`-da`) also exists |
| 155/155 “passed” | Mixed outcomes; `natural_exit = 0`; 6,517 labeled `exception_crash` with `exit_code = null` (collector bug) |
| SkewMask 9/31 re-executions | Fixed N=30: GO 11/30 below threshold (median 3,083.210); GO_DO 30/30 (2,104.770); TMW0 30/30 (2,433.285) |
| AntiDebug 3+3 | Pairing code is correct; 21/10 CSV has **1 run per condition** |
| −87.2% WS / −38.5% CPU | SkewMask **stretches** wall-clock (benign persistent +55.5 s); not a gain |
| No CI | Bootstrap 95% and Wilson already exist |
| Future work 4, 5 and part of 7 (`-da`, NAT/EMPTY, corpus+CI) | Already done in this campaign |
| TMW_DM groupable as “CI includes 0” | Short malicious WS +0.451 MB [0.049; 0.805] **does not include zero** |

## What the article gets right in tone, but the numbers are old

- The metric-validity rule was **not** in `experiment.config.json`. The article already admits it was formalized in the revision. That must remain explicit; do not say it was a priori.
- “There is no behavioral equivalence” remains correct. `FidelityProbe` is **another** pintool and does not run at the same time as TOMWare.
- `TestMemoryScan` counts (212 / 11 / 14 / 18) were not reconfirmed on the 21/10 VM (truncated excerpt). Rerun in Stage 4.

## Letters that **must not** go to the reviewers

The PDFs `Access-2026-38745_Response_to_Reviewers.pdf` and the PT version, plus `MANUSCRIPT_REPLACEMENTS.md`, inherited errors of mine:

1. Treating `crash_exit` as a real crash.
2. N=30 medians by the lower element of the central pair, not the conventional median.
3. Mixing the article’s AntiDebug 3+3 with the CSV’s 1+1.
4. Saying that `sample_count > 0` was in the config a priori.
5. Treating the TMW_DM CI (WS, short malicious) as if it included zero.

Regenerate letters only after Stages 2–9.

## Checkpoint for the coauthor

1. Confirm that this PDF is in fact the current Overleaf (hash above). If there is another export, send it.
2. Agree that **no** phrase of 31 / 3,100 / 10 s / 155/155 / −87% / 9/31 enters the version that goes to IEEE.
3. The module description (Sec. III–V) can stay, with a point review.
4. Next step on the host, without VM: Stage 1 (freeze hashes) and Stage 2 (audit the 9,000 with the correct definitions).
