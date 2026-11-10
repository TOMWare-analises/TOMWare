# Response to each item of the Access-2026-38745 briefing

29/10/2026. Only numbers that are in the CSV/JSON of this pack or in the cited repository. Campaign in the article = 100 PE × 9 × 10 = 9,000. DLL `4BBC6270…F0E6`. Pin 3.28.98749. Snapshot `tomware_go`. Seed 705851366. This is **not** the JCVHT campaign (31 PE / 10 s / 3,100).

The six reviews describe the **old** manuscript (31 / 3,100 / 10 s, unmatched AntiDebug, 9/31, −87.2%). The current PDF (`Access-2026-38745_CURRENT.pdf`, SHA-256 `5CBC8E96…A98020`, 22 pp) **is no longer that text**. The 9,000 attempts **were not rerun**. The raw JSON files **were not rewritten**.

---

## Item 1 — Audit and fix the collector

**Request.** Investigate the 6,517 rows with unavailable exit code and the zero CPUs; distinguish launcher / target / children; record PID, external clock, real exit (including 0); separate launch, collection error, unknown status, timeout, and window; do not turn the old rows into success or crash.

**What exists (preserved).**

| Fact | File | Number |
|---|---|---|
| JSON / triples / expected | `evidencias/completeness.json` | 9,000 / 9,000 / 9,000; duplicates 0 |
| Raw `crash_exit` | the same | 6,517, **all** with null `exit_code` |
| True crash with a known code | `evidencias/campaign_audit_report.md` | **0** |
| Reclassification (without overwriting) | the same | `exited_before_limit_exit_code_unknown` |
| Conditions | completeness | 9 × 1,000 (NAT, EMPTY, TMW0, TMW_DD/DP/DE/DM/DO, TMW_ALL) |

Cause: `Invoke-SingleRun.ps1` read `$proc.ExitCode` after redirect. In PowerShell 5.1 a null compared with `< 0` became `exception_crash` / `exception_code=0x`.

**Code fix (new campaigns, not the 9,000).** `Get-SafeProcessExitCode` in `scripts/Invoke-SingleRun.ps1` (collector v2.1): `Refresh`, `HasExited`, second `WaitForExit()` without timeout. Confirmed in Stage 7: 1,800 runs, 1,600 (88.9%) with an integer exit; true AV `0xC0000005` = 105/1,800, not 72%. Report: `evidencias/exitcode_report.md`. Separate identifier; the 9,000 JSON files are intact.

**Sub-requests, status.**

| Sub-request | Status | Evidence |
|---|---|---|
| Distinguish Pin launcher / target / descendants | Partial on the 9,000; R4.3 has `n_tree` and root WS vs tree | `r43_skewmask_diag/*/resources.csv`. `process_tree.txt` **failed** (`$pid` is a read-only automatic variable in PowerShell) |
| PID, temporal identification, relations | Partial | `resources.csv`: utc ISO, elapsed_ms, root_alive, n_tree. Nominative tree absent in R4.3 |
| Real exit code, including zero | 9,000: 6,517 nulls preserved. R4.3 Native/TMW0: **−1073741511**. TMW_DO after cut: **−1** (`timed_out=true`) | `run_meta.json` |
| Separate launch / collection / unknown / timeout / window | Yes, in the audited reclassification | `campaign_audit_report.md` table `audited_outcome` |
| CPU zero ≠ CPU unavailable | Partial | 9,000 medians still show 0.0 in several arms; R4.3 TMW_DO `root_cpu_ms` ≈ 12.5–13.5 s / 60 s |
| Memory in bytes and conversion | R4.3 in bytes (`peak_ws`). Campaign in MiB (`med_ws_mb`) | Do not mix units |
| Peak = system counter or max of samples | R4.3 = **maximum of samples** (~200 ms) | `tree_ws_peak` |
| Duration by external clock | Yes | `Get-Date` in `Measure-Window` |
| Residual processes | R4.3 kills `pin.exe` / `pinbin.exe` between modes | `Stop-Leftovers`; restore `tomware_go` between modes |
| Validate the collector with controlled oracles (exit 0, ≠0, short, CPU, wait, child) | **Not done as a dedicated battery in this trial** | Stage 7 used 20 short real PE; R4.3 used 3 persistent GUI binaries from the corpus |

**Do not declare fulfilled:** the 6,517 are neither success nor crash. The current PDF already refuses a success rate from them.

---

## Item 2 — Complete the functional validation

For each test: reference, treatment, expected, observed, fixed N, command, logs. TMW_ALL on the corpus does **not** replace this battery.

### AntiDebug — addressed within the declared scope

Six paired + native records: `evidencias/antidebug_n3.csv`.

- NAT and TMW0 (`-q`): PEB.BeingDebugged = 0, NtGlobalFlag = 0, exit 0 (3+3).
- `-gdb -q`: IsDebuggerPresent / PEB.BeingDebugged / PEB.NtGlobalFlag = 1 (3/3).
- `-gdb -dd -q`: the three return to 0 (3/3).

`-gdb` is a **PEB oracle**, not an attached debugger. CheckRemoteDebuggerPresent / ProcessDebugPort / ProcessDebugObjectHandle stayed 0 in every arm of this CSV — they were not the stimulus. Limit the text to the fields that were exercised.

### ProcessEnum — partial

`evidencias/processenum_base.csv` (Toolhelp image `pin.exe`): NAT 0, TMW0 **3**, `-dp` 0, `-da` 0.

Module32 fixture (copy of `version.dll` named `pinvm.dll`, **not** real Pin): `evidencias/module32_fixture.csv` — `-dp`/`-da` remove the pin-ish name; termination `ENUM_OK`. Does not replace `NtQuerySystemInformation`. ANSI/Unicode variants of Process32/Module32/GetModuleHandle are **not** all in this battery.

### SanitizePinEnvVars — partial (`-da` oracle)

`evidencias/da_n10.csv` row `DA3_EV` (`TestGetEnvironments.exe`, `-da -q`): PIN_APP/VM_LD_LIBRARY_PATH and PIN_CRT_TZDATA = 0, exit 0. Not proof of every Windows/CRT query nor of the environment layout outside this oracle.

### InstMemcmpMask — partial

`evidencias/memcmp_n10.csv` (campaign `t2_n10_v7b`, campaign DLL `4BBC6270`):

- `memcmp` / `_memicmp` / `RtlCompareMemory`: PASS in the reference, MASKED with `-dm`/`-da`.
- Legitimate equality and inequality pass-through: OK on the rows.
- `RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `wmemcmp_s`, `bcmp`: ABSENT / NOT_EXERCISED.
- `_memicmp_l` (3 arguments) on the campaign DLL: known ACCESS_FAULT. The 4-argument arrangement is **another** DLL (`D55EC952`) — it does **not** retro-validate the 9,000.

### Combined mode `-da` — 5/5 oracle, not corpus

`da_n10.csv`: AntiDebug, ProcessEnum, Environments, MemoryScan, Overhead (`2042.56 < 3000`), all exit 0, `timed_out=False`. TMW_ALL in the 9,000 is a different thing (1,000 corpus attempts, without those stimuli).

---

## Item 3 — Timing and temporal coherence

**90/90 retained.** `evidencias/matched_timing_n30.csv` + `matched_timing_summary_conventional.csv`.

| Arm | n | median ticks | min–max | below the 3000 threshold |
|---|---|---|---|---|
| TMW0 (`-q`) | 30 | 2433.285 | 2168.12–2749.98 | 30/30 (100%) |
| GO (`-go -q`) | 30 | 3083.210 | 2722.01–3845.31 | 11/30 (36.7%) |
| GO_DO (`-go -do -q`) | 30 | 2104.770 | 2073.28–2146.11 | 30/30 (100%) |

Not repeated until it “passed”. `SkewMask.cpp` was not altered (that would invalidate this table).

**Waits.** The briefing asks for sequential, overlapping, nested, alertable, repeated reads, source consistency, rollback, conversions, duplication. That is **not** closed on the 9,000. The TickCount wait oracle 4/10 and alertable SleepEx 0/10 is **complementary JCVHT** — do not copy it into the Access tables. The Access PDF already admits timeout on the loaded arm and on the treatment. Compensation of the synthetic workload ≠ Pin detection in malware.

---

## Item 4 — Resources and behavior (R4.3, completed today)

**A priori selection rule** (medians `sample_condition_medians.csv`, persistent benign, TMW0 `n_ok=0`, TMW_DO `n_ok≥6`, wall ~60 s):

| ID | SHA-256 | Campaign TMW0 | Campaign TMW_DO |
|---|---|---|---|
| BEN_28 | `0111d485…fa39` | n_ok=0, med_wall=1583 ms | n_ok=8/10, med_wall=60867 ms |
| BEN_46 | `0ab9f292…33a2` | n_ok=0, med_wall=1277 ms | n_ok=7/10, med_wall=60825 ms |
| BEN_47 | `0abd30c5…5dfd` | n_ok=0, med_wall=1380 ms | n_ok=8/10, med_wall=60847 ms |

Family in the manifesto: `Windows_GUI_App`, profile `persistent`, `included=true`. Source `Windows_Environment` 2026-10-14. This is **not** a malware case.

**R4.3 protocol.** Campaign `access_r43_skewmask_diag`. N=1 per arm. Window 60 s. NAT / TMW0 (`-q`) / TMW_DO (`-do -q`). Restore `tomware_go` between modes. `-mc` refused (counters change the cost). DLL checked on each RUN = `4BBC6270…F0E6`.

**Result (source: `run_meta.json`, not the console `exit=0`).**

| Sample | Native | TMW0 | TMW_DO |
|---|---|---|---|
| BEN_28 | EXITED 1609 ms, exit **−1073741511**, peak_ws=0, n_tree=0 | EXITED 1687 ms, **same exit**, peak≈70,164,480, n_tree=3 then 0 | STILL_ALIVE 61016 ms, timed_out, exit **−1**, peak=68,624,384, n_tree=3 until the end |
| BEN_46 | EXITED 781 ms, **−1073741511**, peak_ws=0 | EXITED 1938 ms, **same exit**, peak≈67,272,704 | STILL_ALIVE 61234 ms, timed_out, peak=68,521,984 |
| BEN_47 | EXITED 750 ms, **−1073741511**, peak_ws=0 | EXITED 1703 ms, **same exit**, peak≈71,753,728 | STILL_ALIVE 61062 ms, timed_out, peak=69,128,192 |

`−1073741511` = `STATUS_ENTRYPOINT_NOT_FOUND` (`0xC0000139`). Native: the PE **does not map** (WS=0). TMW0: Pin comes up (~64–72 MB) and falls with the same exit in <2 s. TMW_DO: the **Pin tree** remains 60 s (`root_alive=1`, root CPU ~12.5–13.5 s). `stdout`/`stderr` empty. `identified=false`. `not_a_claim`: alive_is_not_progress; not Arancino; not the 9000.

**Observable progress?** Not determined. No completed operation, no API, no new files, no nominative tree. Classification: **inconclusive as to progress**; the duration difference is **wait / Pin state under `-do`**, not a memory gain and not a working GUI.

**Evasive-malware chain (hash, observed anti-instr., path, knob effect, extra behavior):** **does not exist** in this trial nor in the 9,000. `identify_summary.csv`: `identified=false`. `corpus.csv`: `targeted_evasion=unverified`. IAT ≠ executed branch.

Persistence in the 9,000 (Wilson 95%, persistents, 250/cell): benign TMW0 9.6% → TMW_DO 52.8%; malicious TMW0 32.8% → TMW_DO 57.6%. The PDF already treats this as state, not a gain. R4.3 shows **one compatible mechanism** (Pin alive after a native entry-point failure) — it does **not** rewrite the 9,000.

CTRL_PE / `TestRecoverWork` is **JCVHT**, labeled, and does not count as an Access case.

---

## Item 5 — Baselines and external comparison

**NAT / EMPTY / TMW0.** 1,000 each in the 9,000 (`completeness.json`). Contrast duration/resources beyond outcomes: `outcomes_by_stratum.csv`, `sample_condition_medians.csv`. Persistent benign NAT `protocol_ok` 20/250; TMW0 24/250; TMW_DO 132/250.

**Pin without a Pintool.** Probe `pin.exe -- <target>` is **invalid** on this engine. PIN condition marked `not_supported_by_engine`. EMPTY (`EmptyPinTool.dll` SHA-256 `804BE19B…B153C8`) is the minimum baseline **under Pin**, not the exclusive cost of the engine. Document: `evidencias/empty_tool_and_pin_probe.md`.

Total cost vs NAT ≠ incremental effect vs TMW0. Keep both contrasts. Do not present EMPTY as bare Pin.

**Arancino.** Blocked. `evidencias/BLOQUEIO.md`. Absent from the repo. Public: necst/arancino, Pin **2.14** + VS2010, **32-bit only**. Access corpus: **100/100 x64**. Porting to Pin 3.28 **is not** the published Arancino. COBAI and Peekaboo absent. No ranking. Request **blocked**, not “fulfilled by limitation”.

---

## Item 6 — Manifesto, metrics, statistics, 22/30

**Manifesto.** `evidencias/corpus.csv`: 100 rows, `included=true`, SHA-256, source, date, class, family/type with method (`MalwareBazaar_Consensus` / `Microsoft`), packer/protector (many `unknown`/`none`), x64, profile, `targeted_evasion=unverified`. Unknown information is marked — do not invent VirusTotal.

**Filters.** 120/60 windows and N=10 per cell are a priori. The `sample_count > 0` filter for resources is **post hoc** (it is not in `experiment.config.json`). Methods must say so. Effective `n_pairs` ≠ 25 when only 2 binaries have resources (short-lived benign NAT).

**Statistics.** Bootstrap 2,000, seed **705851366**, conventional medians, Wilson 95% on proportions. No p-values. A CI that contains zero ≠ equivalence.

**22/30.** Exists. `evidencias/fidelity_report.md`. 10 PE × NAT/EMPTY/TMW0/TMW_ALL × 3 = 120. **External** observer (exit + SHA of stdout). TMW0 vs TMW_ALL: 22 pairs equal, 8 different. This is **not** syscall/coverage fidelity. Empty stdout does not demonstrate behavior. The current PDF (correctly) does **not** use 22/30 as proof. FidelityProbe did not run.

---

## Mandatory briefing deliverables

| # | Request | Where in this pack |
|---|---|---|
| 1 | Patch, tests, instructions | `scripts/Invoke-SingleRun.ps1` (v2.1); `scripts/Run-AccessR43.ps1`; `scripts/PASSO_A_PASSO_ACCESS_R43.txt`. **SkewMask.cpp was not altered.** |
| 2 | Manifesto and protocol | `evidencias/corpus.csv`; `evidencias/completeness.json`; R4.3 header in the script |
| 3 | Individual records | `r43_skewmask_diag/*/{run_meta.json,verdict.txt,resources.csv,stdout,stderr,process_tree.txt}`. The 9,000 JSON files **are not** in the zip (size; originals in the repo) |
| 4 | Unavailability / exclusion | 6,517 unknown; Pin-without-tool invalid; Arancino blocked; R4.3 `process_tree.txt` broken; `targeted_evasion=unverified` |
| 5 | Consolidated tables | `evidencias/outcomes_by_stratum.csv`, `sample_condition_medians.csv`, `r43_skewmask_diag/summary.csv` |
| 6 | Commit / versions | HEAD `e382a6c`. Campaign DLL `4BBC6270…F0E6`. Pin 3.28.98749. Campaign collector ≠ v2.1. R4.3 scripts **still untracked** in this HEAD |
| 7 | Report | this file + `03_R43_LEITURA.md` |
| 8 | Matrix of the six reviewers | `02_MATRIZ_SEIS_REVISORES.csv` |

Data **preserved**: 9,000 JSON. **Reanalyzed**: 6,517 reclassification, aggregates. **Recollected**: R4.3 (9 runs, id `access_r43_skewmask_diag`); Stage 7 (1,800, own id, not in this zip).

---

## What remains blocked (do not mark done)

1. Arancino bake-off / COBAI ranking / Peekaboo.
2. Rerun the 9,000 with collector v2.1.
3. API traces / coverage / equivalence.
4. “The malware used the five checks.”
5. An Access case with check → branch → knob → hashed artifact chain on the same PE.
6. Alter SkewMask or repeat N=30.
7. Nominative parent/child tree in R4.3 (`process_tree.txt`).
8. Mix JCVHT 31/10 s with Access 100/9,000.
