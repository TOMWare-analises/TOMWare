# Report — Access-2026-38745 vs evidence in the repository

Date: 29/10/2026. Campaign DLL `4BBC6270`. Pin 3.28.98749. Snapshot `tomware_go`. Seed `705851366`.
Audited PDF: `Access-2026-38745_CURRENT.pdf` (SHA-256 `5CBC8E96…A98020`, 22 pp).

The six reviews describe the **old** manuscript (31 PE / 3,100 / 10 s, unmatched AntiDebug, 9/31, −87.2%). The current PDF **is no longer that text**. I did not rerun the 9,000 attempts. I did not mix the JCVHT campaign.

## What I checked in the CSVs (not in the prose)

| Fact | File | Number |
|-------|----------|--------|
| 9,000 JSON, 9,000 triples, 0 duplicates | `experiment/results/campaign/corpus_aligned_10k/completeness.json` | 9 conditions × 1,000 |
| Raw `crash_exit` | the same | 6,517, all with null `exit_code` |
| True crash with a code | audit | **0** |
| Reclassification | `notes/campaign_audit_report.md` | `exited_before_limit_exit_code_unknown` |
| Table 19 short-lived TMW0 | `outcomes_by_stratum.csv` summed | 406 without code + 88 timeout + 6 launch = 500 |
| Table 19 persistent TMW0 | same | 371 + 106 window + 23 launch = 500 |
| AntiDebug 3/3 vs 3/3 | `oracles/guest/antidebug_n3.csv` | `-gdb -q` positive; `-gdb -dd -q` OK |
| Timing N=30 | `matched_timing_summary_conventional.csv` | TMW0 30/30; GO 11/30 (36.7%); GO_DO 30/30 |
| `-da` oracles | `da_n10.csv` | 5/5 exit 0 (Overhead 2042.56 < 3000) |
| ProcessEnum oracle | `processenum_base.csv` | NAT 0 pin.exe; TMW0 3; `-dp` 0; `-da` 0 |
| Corpus 100 | `experiment/corpus/corpus.csv` | 50+50, x64, `included=true` |
| Arancino | `oracles/arancino/BLOQUEIO.md` | absent; Pin 2.14; 32-bit only |
| 22/30 exit+stdout | `notes/fidelity_report.md` | external observer; **not** API/coverage |

The current PDF already uses 100 PE, 9,000, matched AntiDebug, 11/30→30/30, Table 19 with “no code”, and refuses behavioral equivalence. That answers most of the six reviews **with data that were already in the tree**.

## Collector (briefing request 1)

Cause of the 6,517: `Invoke-SingleRun.ps1` read `$proc.ExitCode` after redirect; in PowerShell 5.1 a null compared with `< 0` became `exception_crash` / `0x`. The original JSON files **were not altered**.

Code fix (new campaigns): `Get-SafeProcessExitCode` in `experiment/scripts/runner/Invoke-SingleRun.ps1` (v2.1) — `Refresh`, `HasExited`, second `WaitForExit()` without timeout. Confirmed separately in Stage 7 (1,800 runs, 88.9% with an integer exit; true AV 105/1,800, not 72%).

Do not turn the 6,517 into success or crash. The PDF already says: a success rate is not computed from them.

## Functional validation (briefing request 2)

Addressed on the `4BBC6270` campaign oracles, with the following scope:

- AntiDebug: only PEB `BeingDebugged` / `NtGlobalFlag` and the `-gdb` stimulus. Not an attached debugger.
- ProcessEnum: `TestProcessEnum` Toolhelp image `pin.exe`. ANSI/Unicode/Module32 variants exist in auxiliary CSVs (`module32_fixture.csv`); they do not replace `NtQuerySystemInformation`.
- SanitizePinEnvVars / InstMemcmpMask / `-da`: `da_n10.csv` and `memcmp_n10.csv`. On the campaign DLL, 3-argument `_memicmp_l` still ACCESS_FAULT; the 4-argument arrangement is DLL `D55EC952`, a **different** identity — do not retro-validate the 9,000.
- TMW_ALL on the corpus does not replace the oracle battery; the two exist and must remain separate.

## Timing (briefing request 3)

The 90 rows of `matched_timing_n30.csv` are retained. Do not repeat until it “passes”. Concurrent waits under Pin: timeout on the loaded arm and on the treatment (limitation in the PDF). TickCount 4/10 and alertable SleepEx 0/10 are from the complementary **JCVHT** campaign; do not copy them into the Access 9,000 tables.

## Resources and behavior (briefing request 4)

The Access PDF **no longer carries −87.2 / −38.5**. Under the 60 s window, TMW_DO increases the fraction that remains observable (persistent benign TMW0 24/250 → TMW_DO 132/250). That is a state / wait change, not a gain. There are, in the 9,000, neither API traces nor bytes written per persistent binary. The `TestRecoverWork` demonstrator (CTRL_PE) is **JCVHT**, labeled, and does not count as an Access case.

## Baselines and Arancino (briefing request 5)

NAT / EMPTY / TMW0 / five knobs / TMW_ALL: 1,000 each. Pin-without-tool probe invalid — EMPTY does not isolate the engine. Arancino: **blocked** (`BLOQUEIO.md`). COBAI and Peekaboo absent. Do not fabricate a ranking.

## Manifesto and statistics (briefing request 6)

`corpus.csv` is the manifesto. Evasion on the 50 malware = `unverified`. Bootstrap 2,000 and seed 705851366 are in `manuscript_values.json` and in the PDF. The `sample_count > 0` filter was **not** in `experiment.config.json` — it remains retrospective; Methods must say so. 22/30 exists and is documented; it is **not** behavioral fidelity; the current PDF (correctly) does not use it as proof.

## What I will **not** mark as done

| Request | Why |
|--------|--------|
| Arancino bake-off | Different ISA, Pin generation, OS, and corpus |
| Rerun 9,000 with collector v2.1 | New campaign; the old JSON stays |
| API traces / coverage | Stage 6 was an external observer |
| “The malware used the five checks” | `identified=false` / `unverified` |
| Alter `SkewMask.cpp` or repeat N=30 | Would invalidate the timing table already in the PDF |
| Mix JCVHT 31/10 s with Access 100/9,000 | Distinct protocols |

## R4.3 (29/10/2026) — persistence diagnostic

Three persistent benign binaries (BEN_28/46/47), NAT / TMW0 / TMW_DO, 60 s, DLL `4BBC6270`, id `access_r43_skewmask_diag`. Native and TMW0: `EXITED_BEFORE_WINDOW`, exit `−1073741511` (`STATUS_ENTRYPOINT_NOT_FOUND`). TMW_DO: `STILL_ALIVE_AT_WINDOW` ~61 s (Pin tree, `n_tree=3`). `identified=false`. Reading: wait/state, not progress, not a rewrite of the 9,000. Detail: `03_R43_LEITURA.md`.

## Letter

English already versioned: `experiment/validation/manuscript/Access-2026-38745_Response_to_Reviewers.pdf`. Use the CSV matrix in this folder to check each item before resubmitting. Do not commit `.env` or samples. Collaborator pack: folder/zip `Access-2026-38745_ANALISE_AMIGO_2026-10-29` in Downloads. Do **not** send that zip to IEEE.
