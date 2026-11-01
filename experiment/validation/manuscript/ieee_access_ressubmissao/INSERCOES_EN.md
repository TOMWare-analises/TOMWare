# English manuscript inserts — Access-2026-38745

Paste into the Overleaf/Word source. Replace every remaining Portuguese evaluation page. Do not mix JCVHT 31 PE / 10 s / 3,100 cells. Numbers are from audited CSVs only.

Campaign identity: git `58ea738020681318c5a65eb1cdae02b1ea82b922` (https://github.com/TOMWare-analises/TOMWare); Intel Pin 3.28.98749; campaign DLL SHA-256 `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`; EmptyPinTool `804BE19BF7924B641FE25F07EA89DEC26DC9DAA36C49638F407FF96E2AB153C8`; snapshot `tomware_go`; seed 705851366; bootstrap 2,000; corpus `experiment/corpus/corpus.csv`. The stamp commit that only writes this hash is recorded in `REPRODUCIBILITY.txt`.

---

## 1. Observable-output diagnostic (22/30) — paste in Results (VI), not only the Introduction

The current PDF mentions 22 of 30 pairs only in the Introduction. Move the full account into Section VI.

A separate diagnostic, not part of the 9,000-attempt corpus, compared TMW0 (`-q`) with TMW_ALL (`-da`) under an external observer (`external_ps`). The observer recorded the process exit code and the SHA-256 of standard output. It did not record API traces, basic-block coverage, or kernel events. FidelityProbe was not run. Guest timeout: 45 s. Raw: `experiment/results/oracles/fidelity_by_run.csv`.

Ten executables (BEN_05, BEN_06, BEN_10, BEN_12, BEN_14, MAL_01, MAL_02, MAL_06, MAL_07, MAL_11) × three independent repetitions = 30 TMW0–TMW_ALL pairs.

**Agreement criterion:** equal exit code and equal stdout SHA-256. An empty stdout is hashed as the empty buffer; that agreement is still only an external observable.

**Result:** 22 of 30 pairs agreed; 8 disagreed.

| Pair | TMW0 | TMW_ALL | Reading |
|---|---|---|---|
| BEN_06 × 3 | exit 3 | timeout (`-2`) | Combined activation changed the recorded outcome |
| BEN_12 × 2 | exit 0, stdout 754 B | timeout; the finished attempt kept the same 754 B hash | Text matched when the process exited; two attempts did not exit in time |
| MAL_06 × 1 | exit 0 | exit 2 | One of three repetitions differed |
| MAL_07 × 2 | exit 0 | `0xC0000005` | Combined activation worsened termination |

This diagnostic does not demonstrate equivalence of APIs, control flow, or external effects (files, registry, or network). Longer wall-clock under TMW_ALL in several agreeing pairs is cost, not a fidelity gain.

---

## 2. ProcessEnum and the Module32 fixture — REPLACE denials in V-B, VI-C, VII-A

The current PDF still says there is no Module32 positive control. That is false once `module32_fixture.csv` is inserted. Exact replacements: `PATCH_VB_VIC_VIIA_EN.md`.

`TestProcessEnum.exe` (Unicode process enumeration) reported three `pin.exe` entries under TMW0 and zero under `-dp` and `-da` (`processenum_base.csv`).

A complementary fixture loaded a **copy of `C:\Windows\System32\version.dll` named `%TEMP%\pinvm.dll`**. That file is a dummy name, **not** the real Pin module. Native and TMW0 enumerated it. Under `-dp -q` and `-da -q` the fixture was hidden; `kernel32.dll` stayed visible; enumeration terminated (`ENUM_OK`). Counts: 32 / 31 / 30 / 30.

The fixture does not validate `NtQuerySystemInformation` and does not individually validate every `GetModuleHandleA`/`GetModuleHandleW` calling pattern.

---

## 3. Combined mode `-da` (five oracles) — `da_n10.csv` is five rows, not ten repetitions

The filename belongs to campaign id `t2_n10_v7b`. The file has **one execution per oracle**:

| Oracle | Knobs | Exit | Timed out | Duration (ms) | Note |
|---|---|---|---|---|---|
| TestAntiDebug | `-gdb -da -q` | 0 | no | 10316 | PEB fields 0 |
| TestProcessEnum | `-da -q` | 0 | no | 13413 | `pin.exe` 0 |
| TestGetEnvironments | `-da -q` | 0 | no | 13324 | `PIN_*` 0 |
| TestMemoryScan | `-da -q` | 0 | no | 44062 | monitored signatures 0 |
| TestOverhead | `-da -q` | 0 | no | 14658 | 2042.56 < 3000 |

This is a basic functional smoke test. It does not prove the absence of module interactions across the 100-binary corpus. TMW_ALL in the 9,000 attempts is a separate operational arm.

---

## 3b. InstMemcmpMask family controls (campaign DLL `4BBC6270`)

`TestMemoryScan.exe` still documents `memcmp` signature counts (Table 12). In addition, `memcmp_n10.csv` records one run per configuration:

| Configuration | Exit | `memcmp` PIN | `_memicmp` PIN | `RtlCompareMemory` PIN |
|---|---|---|---|---|
| Native | 0 | PASS | PASS | PASS |
| TMW0 (`-q`) | 0 | PASS | PASS | PASS |
| `-dm -q` | 2 | MASKED | MASKED | MASKED |
| `-da -q` | 2 | MASKED | MASKED | MASKED |

Legitimate equality and inequality (pass-through) on those three routines remained OK. NOT_EXERCISED / ABSENT: `RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `wmemcmp_s`, `bcmp`. `_memicmp_l` is FOUND; NAT/TMW0 PASS; `-dm`/`-da` MASKED then `ACCESS_FAULT` (3-argument hook versus 4-argument CRT). Later DLL `D55EC952` does **not** retroactively validate the 9,000.

---

## 4. Additional SkewMask diagnostic (access_r43)

Three persistent benign binaries were selected a priori from `sample_condition_medians.csv` (TMW0 `n_ok=0`, TMW_DO `n_ok≥6`, wall-clock near 60 s): BEN_28, BEN_46, BEN_47. One run per condition (NAT, TMW0 `-q`, TMW_DO `-do -q`), 60 s window, campaign DLL, snapshot `tomware_go`, campaign id `access_r43_skewmask_diag`. Counters (`-mc`) were off.

On `access_r43b_process_tree` (named trees; `access_r43_skewmask_diag` preserved), Native terminated with exit `−1073741511` (`STATUS_ENTRYPOINT_NOT_FOUND`, `0xC0000139`) and peak WS $=0$. TMW0 BEN_28 and BEN_46 exited with the same code at 1625 ms; BEN_46 left a named tree `pin.exe` → sample + `conhost.exe`. TMW_DO BEN_46 remained `STILL_ALIVE_AT_WINDOW` at 61063 ms with that tree. TMW_DO BEN_28 had `n_tree=3` for about 49 s and then exited `−1073741511`. BEN_47 TMW0/TMW_DO is Pin Win32 740 (elevation required). `identified=false`.

Persistence is therefore a change of execution state or wait under `-do`, not evidence that the application made progress.

---

## 5. The 6,517 unavailable exit codes

In the 9,000 JSON records, 6,517 rows were stored as `exception_crash` with a null `exit_code` and `exception_code=0x`. After `Start-Process` with redirected streams, Windows PowerShell 5.1 can leave `Process.ExitCode` unpopulated; a null compared with `< 0` was treated as a crash. True crashes with a known exit code in those 9,000 records: 0.

The audited label is **termination with unavailable exit code** (`exited_before_limit_exit_code_unknown`). The original JSON files were not rewritten. Collector v2.1 (`Get-SafeProcessExitCode` in `Invoke-SingleRun.ps1`) applies only to later campaigns (confirmation: 1,800 runs, 88.9% integer exit). A success rate is not computed from the 6,517 rows.

---

## 6. Recorded CPU values of zero

A recorded CPU value of zero does not mean that the processor did no work. The origin of the many zeros could not be validated from the stored series (`sample_count` often too small; collector resolution). CPU is reported only as a descriptive record. No conclusive CPU cost or saving percentage is claimed. Under TMW_DO, recorded CPU can rise simply because the process remains scheduled until the 60 s window.

---

## 7. Baselines

| Condition | Meaning |
|---|---|
| NAT | No Pin |
| EMPTY | Pin + `EmptyPinTool.dll` (no hooks) |
| TMW0 | Pin + `TOMWare.dll`, all five knobs off (`-q`) |
| TMW_DD/DP/DE/DM/DO | One knob (`-dd`, `-dp`, `-de`, `-dm`, `-do`) |
| TMW_ALL | All five (`-da`) |

A probe of Pin without a Pintool (`pin.exe -- target`) was not supported by this Pin 3.28 configuration (`not_supported_by_engine`). EMPTY is the smallest viable Pin-hosted reference. It is not exclusively the internal cost of the Pin engine (tool load and injection remain).

---

## 8. Two contrasts

- **Total instrumentation cost:** NAT versus EMPTY or TMW0.
- **Incremental countermeasure effect:** TMW0 versus the enabled module (or TMW_ALL).

TMW0 versus an enabled module is not the total cost of Intel Pin.

---

## 9. Corpus manifesto

The 100-row manifesto is `experiment/corpus/corpus.csv` in https://github.com/TOMWare-analises/TOMWare (columns: SHA-256, source, acquisition date 2026-10-14, class, coarse type, architecture x64, profile, packer/protector, `targeted_evasion`). `Trojan_Bazaar` and `Backdoor_Bazaar` are coarse MalwareBazaar labels, not VirusTotal families. Packer/protector remains `unknown` on the malware rows. `targeted_evasion=unverified` for all 50 malicious binaries and `none` for the 50 benign binaries.

---

## 10. Resource filters are post hoc

Windows 120 s / 60 s and N=10 per cell were fixed before the 9,000 attempts. The resource-contrast filter (finite positive duration in both conditions; finite memory; at least one resource sample, operationally `sample_count>0` and `peak_working_set_bytes>0`) was **not** present in `experiment/config/experiment.config.json` and is retrospective. It retained 98 pairs. MAL_33 and MAL_37 had zero duration and no resource samples in both conditions and were excluded from those contrasts only; their operational outcomes remain in the 9,000-row tables. Effective `n_pairs` is not always 25. Intervals are exploratory. Do not present this filter as prospective.

---

## 11. Routines implemented but not individually validated

The following are implemented in the Pintool but were not given individual positive and negative controls in this revision: `GetModuleHandleA`/`W` beyond the process-oracle and dummy-fixture setting; ANSI and Unicode enumeration variants as a full matrix; `RtlEqualMemory`; `wmemcmp`; `memcmp_s`; `wmemcmp_s`; `bcmp`; `_memicmp_l`. On the campaign DLL, `RtlEqualMemory` and `wmemcmp` were ABSENT/`NOT_EXERCISED`. The article must say they are implemented but not individually validated. The campaign-DLL `_memicmp_l` (3-argument) ACCESS_FAULT is a known limitation; a later 4-argument build is a different DLL identity and does not revalidate the 9,000.

---

## 12. Temporal coherence still pending

Not validated: overlapping, concurrent, nested, and alertable waits; repeated clock reads during offset updates; consistency across timing sources; double counting of intervals; and monotonicity / rollback checks. Existing wait timeouts (instrumented load and treatment) are **inconclusive**. TickCount 4/10 and alertable SleepEx 0/10 belong to the separate JCVHT campaign and must not be copied into Access tables. SkewMask is compensation of the specific `TestOverhead` oracle (11/30 versus 30/30 at N=30), not a proof of Pin concealment or malware efficacy.

---

## 13. Behavioral equivalence is not demonstrated

The 9,000 records and the 22/30 diagnostic do not include API traces, code coverage, named descendant processes suitable for attribution, application progress milestones, or file/registry/network effects. Behavioral equivalence is not demonstrated. Operational completion or remaining observable is not transparency.

---

## 14. No practical evasive malware case

A case would require (1) an identified Pin check, (2) a branch taken because of that result, (3) a change after enabling the matching knob, and (4) additional observed behavior, on the same malicious executable and input, with a hashed artifact. That chain does not exist in the Access corpus. Imports, strings, IAT hits, and persistence are not evidence of evasion. `identified=false`; `targeted_evasion=unverified`.

---

## 15. Arancino

No direct experimental benchmark was run. Public Arancino targets Pin 2.14 and Visual Studio 2010 and supports 32-bit binaries only. This campaign uses Pin 3.28 and a 100/100 x64 corpus. A bake-off would confound Pin generation, ISA, OS, and corpus. Porting the 2017 source to Pin 3.28 would not be the published tool. Only the architectural table is retained. No superiority is claimed. A shared 32-bit protocol remains future work (`BLOQUEIO.md`).

---

## 17. Abstract, discussion, and conclusion (must match)

- AntiDebug is limited to the PEB fields exercised under `-gdb`.
- SkewMask is compensation of the specific timing oracle.
- 22/30 is limited agreement of external observables.
- Persistence is not proof of application progress.
- No recovered malicious behavior is claimed.
- No universal transparency is claimed.
- No experimental comparison with Arancino exists.

---

## 20. Campaigns remain separate

IEEE Access: 100 PE × 9 × 10 = 9,000; windows 120 s (short-lived) and 60 s (persistent). JCVHT: 31 PE, 10 s, 3,100. Do not share cells, hashes, or wait-table numbers across the two papers.
