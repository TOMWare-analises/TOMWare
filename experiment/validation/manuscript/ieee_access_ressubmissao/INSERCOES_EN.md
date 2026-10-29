# English manuscript inserts — Access-2026-38745

Paste into the Overleaf/Word source. Replace every remaining Portuguese evaluation page. Do not mix JCVHT 31 PE / 10 s / 3,100 cells. Numbers are from audited CSVs only.

Campaign identity (also item 16 after the commit): Intel Pin 3.28.98749; campaign DLL SHA-256 `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`; EmptyPinTool `804BE19BF7924B641FE25F07EA89DEC26DC9DAA36C49638F407FF96E2AB153C8`; snapshot `tomware_go`; seed 705851366; bootstrap 2,000; corpus `experiment/corpus/corpus.csv`.

---

## 1. Observable-output diagnostic (22/30)

A separate diagnostic, not part of the 9,000-attempt corpus, compared TOMWare with all knobs off (TMW0, `-q`) to combined activation (TMW_ALL, `-da`) under an external observer. The observer recorded the process exit code and the SHA-256 hash of standard output. It did not record API traces, basic-block coverage, or kernel events. FidelityProbe was not run.

Ten executables were used (BEN_05, BEN_06, BEN_10, BEN_12, BEN_14, MAL_01, MAL_02, MAL_06, MAL_07, MAL_11), three independent repetitions each, yielding 30 TMW0–TMW_ALL pairs. The guest timeout was 45 s. Raw rows: `experiment/results/oracles/fidelity_by_run.csv`.

Agreement was defined as equal exit code and equal stdout SHA-256. Under that definition, 22 of 30 pairs agreed and 8 disagreed. Empty stdout was hashed as the empty buffer; agreement on an empty buffer is still only an external observable.

The eight disagreements were:

| Pair | TMW0 | TMW_ALL | Reading |
|---|---|---|---|
| BEN_06 × 3 | exit 3 | timeout (`-2`) | Combined activation changed the recorded outcome |
| BEN_12 × 2 | exit 0, stdout 754 B | timeout; same 754 B hash on the finished attempt | Text matched when the process exited; two attempts did not exit in time |
| MAL_06 × 1 | exit 0 | exit 2 | One of three repetitions differed |
| MAL_07 × 2 | exit 0 | `0xC0000005` | Combined activation worsened termination |

This diagnostic does not demonstrate equivalence of APIs, control flow, or external effects (files, registry, or network). Duration also increased under TMW_ALL in several agreeing pairs; longer wall-clock is cost, not a fidelity gain.

---

## 2. ProcessEnum and the Module32 fixture

`TestProcessEnum.exe` (Unicode process enumeration) reported three `pin.exe` entries under TMW0 and zero under `-dp` and `-da` (`processenum_base.csv`).

A complementary fixture, `module32_fixture.csv`, loaded a copy of `version.dll` as `%TEMP%\pinvm.dll`. That file is a dummy name, not the real Pin module. Under `-dp` and `-da` the fixture name was hidden (`fixture_pinvm=0`, `pinish=0`). `kernel32.dll` remained visible. Enumeration terminated (`ENUM_OK`). Module counts were 32 (native), 31 (TMW0), and 30 (`-dp` / `-da`).

The fixture does not validate `NtQuerySystemInformation` and does not individually validate every `GetModuleHandleA`/`GetModuleHandleW` calling pattern.

---

## 3. Combined mode `-da` (five oracles)

One run per oracle, knobs `-da -q` (AntiDebug also used `-gdb -da -q`), campaign `t2_n10_v7b`, `da_n10.csv`:

| Oracle | Exit | Note |
|---|---|---|
| TestAntiDebug | 0 | PEB fields 0 |
| TestProcessEnum | 0 | `pin.exe` 0 |
| TestGetEnvironments | 0 | `PIN_*` 0 |
| TestMemoryScan | 0 | monitored signatures 0 |
| TestOverhead | 0 | 2042.56 < 3000 |

This is a basic functional smoke test. It does not prove the absence of module interactions across the 100-binary corpus. TMW_ALL in the 9,000 attempts is a separate operational arm.

---

## 4. Additional SkewMask diagnostic (access_r43)

Three persistent benign binaries were selected a priori from `sample_condition_medians.csv` (TMW0 `n_ok=0`, TMW_DO `n_ok≥6`, wall-clock near 60 s): BEN_28, BEN_46, BEN_47. One run per condition (NAT, TMW0 `-q`, TMW_DO `-do -q`), 60 s window, campaign DLL, snapshot `tomware_go`, campaign id `access_r43_skewmask_diag`. Counters (`-mc`) were off.

NAT and TMW0 terminated with exit `−1073741511` (`STATUS_ENTRYPOINT_NOT_FOUND`, `0xC0000139`) in 750–1938 ms. Native peak working set was 0. TMW0 mapped Pin (~64–72 MB) and then failed with the same exit. TMW_DO kept the Pin process tree alive for about 61 s (`timed_out=true`, `n_tree=3`, root CPU about 12.5–13.5 s). Standard output and standard error were empty. `identified=false`.

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
