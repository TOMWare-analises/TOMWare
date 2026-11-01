# Access-2026-38745 — English replacement text (integral revision)

Base article: English PDF SHA-256 `CFD80F0D0EE9…` (22 pages). Existing Tables 1–20 keep their numbers. New material is Tables 21–27. Wrap every newly inserted or replacement sentence with `\hl{...}` in the highlighted compile.

The IEEE `.tex` is not in this repository. Paste these replacements into Overleaf. The compiled addendum PDFs merge Tables 21–27 onto the 22-page base. Do not restore Portuguese evaluation pages. Do not mix JCVHT 31/3,100/10 s cells.

Campaign identity is git `a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3` (`REPRODUCIBILITY.txt`). Pin 3.28.98749; campaign DLL `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`; EmptyPinTool `804BE19BF7924B641FE25F07EA89DEC26DC9DAA36C49638F407FF96E2AB153C8`; snapshot `tomware_go`; seed 705851366.

---

## Introduction (keep 22/30, but expand in Section VI)

Keep the existing Introduction sentence that 22 of 30 pairs agreed on exit status and stdout hashes. Add: the full method, sample list, three repetitions, agreement criterion, and the eight disagreements appear in Section VI and Table 24. The diagnostic is not API equivalence.

---

## V-B ProcessEnum — REPLACE the TestModule32 paragraph (after Table 6)

DELETE these statements from the English CFD80 PDF:

- “These records verify enumeration termination and the availability of an unfiltered entry, but do not demonstrate concealment of a monitored module.”
- “The presented records do not include specific positive controls for module concealment through Module32* or GetModuleHandleA/W.”

REPLACE with:

The process oracle `TestProcessEnum.exe` used Unicode process enumeration and found three entries named `pin.exe` in the baseline and none with `-dp` or `-da`. Table 6 reports one execution per configuration; the three baseline entries do not represent three independent repetitions.

A separate positive control exercised Module32 filtering (`module32_fixture.csv`). A copy of `C:\Windows\System32\version.dll` was loaded as `%TEMP%\pinvm.dll`. That file is a dummy name; it is not the real Pin module. Native and TMW0 (`-q`) enumerated the fixture (`fixture_pinvm=1`). With `-dp -q` and `-da -q` the fixture name was hidden (`fixture_pinvm=0`). `kernel32.dll` remained visible in all four runs. Enumeration terminated (`ENUM_OK`). Module counts were 32 (native), 31 (TMW0), and 30 (`-dp` and `-da`). Table 21 reports one execution per configuration.

This fixture does not validate `NtQuerySystemInformation` and does not individually validate every `GetModuleHandleA`/`GetModuleHandleW` calling pattern. ANSI and Unicode Process32/Module32 variants were not exercised as a full matrix. The `-da` row in Table 21 is the Module32 fixture under combined knobs; it does not establish combined validation of all five modules on the 100-binary corpus.

**Table 21.** Module32 positive control. Dummy `%TEMP%\pinvm.dll` is a copy of `version.dll`, not a real Pin module. Source: `module32_fixture.csv`.

| Configuration | Knobs | Exit | Modules | kernel32.dll | fixture pinvm.dll |
|---|---|---|---|---|---|
| Native | — | 0 | 32 | visible | visible |
| TMW0 | `-q` | 0 | 31 | visible | visible |
| ProcessEnum | `-dp -q` | 0 | 30 | visible | hidden |
| Combined | `-da -q` | 0 | 30 | visible | hidden |

---

## Combined `-da` smoke test — INSERT after the five oracle subsections (or in VI-C)

The filename `da_n10.csv` belongs to campaign id `t2_n10_v7b`. It contains five rows, one execution per oracle, not ten repetitions of combined mode. Campaign DLL `4BBC6270`. All five oracles exited 0. `TestOverhead.exe` scored 2042.56, below the calibrated threshold of 3000. This is a functional smoke test. It does not prove the absence of module interactions on the 100-binary corpus. TMW_ALL in Table 19 is a separate operational arm.

**Table 22.** Combined-mode smoke test (`-da`). One execution per oracle.

| Oracle | Knobs | Exit | Timed out | Duration (ms) |
|---|---|---|---|---|
| TestAntiDebug | `-gdb -da -q` | 0 | no | 10316 |
| TestProcessEnum | `-da -q` | 0 | no | 13413 |
| TestGetEnvironments | `-da -q` | 0 | no | 13324 |
| TestMemoryScan | `-da -q` | 0 | no | 44062 |
| TestOverhead | `-da -q` | 0 | no | 14658 |

---

## InstMemcmpMask — REPLACE “restricted to memcmp” (keep Table 12)

Keep Table 12 (`memcmp` signature counts: 212, 11, 14, 18 under `-q`; zero under `-dm -q`). DELETE: “The functional evidence presented is restricted to the memcmp comparisons exercised by the oracle.”

REPLACE the remainder of V-D controlled validation with:

On campaign DLL `4BBC6270`, intercepted PIN-string comparisons were PASS under native and TMW0 and MASKED under `-dm -q` and `-da -q` for `memcmp`, `_memicmp`, and `RtlCompareMemory` (Table 23). Legitimate equality and inequality (pass-through) remained OK on those three routines. Length-zero `memcmp` returned 0. `RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `wmemcmp_s`, and `bcmp` were ABSENT / NOT_EXERCISED (`GetProcAddress` did not yield a usable export). They are implemented in the Pintool but were not individually validated in this revision.

`_memicmp_l` is exported by `msvcrt.dll` (`FOUND`). Under native and TMW0 the PIN-string control was PASS. Under `-dm` and `-da` the PIN-string path printed MASKED and the subsequent pass-through control aborted with `RECEIVED_ACCESS_FAULT` at `0xffffffffffffffff` (exit 2). The campaign wrapper treated `_memicmp_l` as a three-argument routine; the CRT export takes a fourth locale argument. A later build (`D55EC952`, four-argument hook) is a different DLL identity and does not retroactively validate the 9,000-attempt campaign, which used `4BBC6270`.

**Table 23.** Comparison-family controls on campaign DLL `4BBC6270` (`memcmp_n10.csv`), one execution per configuration.

| Configuration | Exit | memcmp PIN | _memicmp PIN | RtlCompareMemory PIN |
|---|---|---|---|---|
| Native | 0 | PASS (ret=0) | PASS (ret=0) | PASS (n=4) |
| TMW0 `-q` | 0 | PASS | PASS | PASS |
| `-dm -q` | 2 | MASKED (ret=1) | MASKED (ret=1) | MASKED (n=0) |
| `-da -q` | 2 | MASKED | MASKED | MASKED |

---

## Section VI — INSERT 22/30 diagnostic (not Introduction-only)

A separate diagnostic, not part of the 9,000-attempt corpus, compared TMW0 (`-q`) with TMW_ALL (`-da`) under an external observer (`external_ps`). The observer recorded the process exit code and the SHA-256 of standard output. It did not record API traces, code coverage, or kernel events. FidelityProbe was not run. Guest timeout: 45 s. Raw: `fidelity_by_run.csv`.

Ten executables (BEN_05, BEN_06, BEN_10, BEN_12, BEN_14, MAL_01, MAL_02, MAL_06, MAL_07, MAL_11) × three independent repetitions = 30 TMW0–TMW_ALL pairs.

Agreement criterion: equal exit code and equal stdout hash field. A 0-byte stdout leaves the hash field **empty**; it is not the SHA-256 of a zero-length buffer (`e3b0c442…`). Two empty fields are equal fields. Of the 22 agreeing pairs, 12 are empty-field agreements and 10 compare a non-empty SHA-256. Derived: `fidelity_pairs_2230.csv`.

Result: 22 of 30 pairs agreed; 8 disagreed (Table 24). This diagnostic does not demonstrate equivalence of APIs, control flow, or external effects (files, registry, or network). Longer wall-clock under TMW_ALL in several agreeing pairs is cost, not a fidelity gain. Per-binary hook-invocation counters were not collected in the 9,000 JSON (`module_counters` off).

**Table 24.** External-observer diagnostic, TMW0 versus TMW_ALL, 10 executables × 3 repetitions = 30 pairs.

| Pairs | TMW0 | TMW_ALL | Reading |
|---|---|---|---|
| 22/30 | — | — | exit equal and stdout hash field equal (12/22 are empty-field / 0-byte stdout) |
| BEN_06 × 3 | exit 3 | timeout (−2) | combined mode changed the outcome |
| BEN_12 × 2 | exit 0, 754 B stdout | timeout; finished attempt kept the same hash | text matched when the process exited |
| MAL_06 × 1 | exit 0 | exit 2 | one of three repetitions differed |
| MAL_07 × 2 | exit 0 | 0xC0000005 | combined mode worsened termination |

---

## VI-B Corpus, manifesto, NAT/EMPTY/TMW0, Pin-without-tool

The 100-row manifesto is `experiment/corpus/corpus.csv`. Columns: SHA-256, source, acquisition date 2026-10-14, class, coarse type, architecture x64, profile, packer/protector, `targeted_evasion`. `Trojan_Bazaar` and `Backdoor_Bazaar` are coarse MalwareBazaar labels, not VirusTotal families. Packer/protector remains `unknown` on the malware rows. `targeted_evasion=unverified` for all 50 malicious binaries and `none` for the 50 benign binaries.

Nine conditions were evaluated: native execution (NAT), Pin with an empty Pintool (EMPTY), TOMWare.M with modules disabled (TMW0), each of the five countermeasures individually, and joint activation of all modules. Two contrasts are separated. Total instrumentation cost is NAT versus EMPTY or TMW0. Incremental countermeasure effect is TMW0 versus the enabled module. TMW0 versus a module is not the total cost of Intel Pin.

Table 26 and `nat_empty_tmw0_table.csv` report NAT, EMPTY, and TMW0 together. Short-lived benign binaries (`n=25`): median of per-binary medians NAT 0.260 s, EMPTY 1.485 s, TMW0 1.973 s (260.0 / 1484.8 / 1973.5 ms). Paired deltas (bootstrap 2,000, seed 705851366): EMPTY−NAT +1.166 s [0.955, 2.553]; TMW0−NAT +1.277 s [1.019, 2.441]; TMW0−EMPTY +0.151 s [0.026, 0.270]. NAT CPU and working-set are missing for 23 of 25 of those binaries; CPU zeros under EMPTY/TMW0 remain descriptive.

Table 27 uses only a validated guest `C:\TOMWare\pin\pin.exe` (SHA-256 `920A730A…0BB819`) run of `pin.exe -- TestAntiDebug.exe`. The host 30 Oct StartServer probe (`FBA632E4…`, `intel64\bin`) is withdrawn from Table 27 and is not incompatibility proof. Guest N=3 (`pin_bare_guest_n3`) is pending ingest; until those three raw folders are on the host, campaign Pin-without-tool incompatibility is **not confirmed**. The 22 Oct `pin_probe.csv` row remains historical (exit 0, empty stderr, oracle OK; pin SHA not stored). `campaign.json` `pin_condition_valid=false` is the 14 Oct design record that omitted PIN from the 9,000. EMPTY remains the smallest Pin-hosted reference in the 9,000.

**Table 26.** NAT / EMPTY / TMW0, short-lived benign, n=25. Full four-stratum CSV: `nat_empty_tmw0_table.csv`.

| Condition | Meaning | Median wall-clock (s) | 95% CI (s) |
|---|---|---|---|
| NAT | no Pin | 0.260 | [0.254, 0.272] |
| EMPTY | Pin + EmptyPinTool | 1.485 | [1.282, 2.830] |
| TMW0 | Pin + TOMWare, knobs off | 1.973 | [1.398, 3.076] |

**Table 27.** Guest Pin-without-Pintool, N=3, campaign launcher only.

| Rep | Launcher | Engine (recorded file) | Oracle | Exit | ms | Timeout | Conclusion |
|---|---|---|---|---|---|---|---|
| 1 | `920A730A…0BB819` | `FBA632E4…741A` `intel64\bin\pin.exe` | `3B25069E…CECD` | 0 | 2963 | no | completed_ok |
| 2 | same | same | same | 0 | 1948 | no | completed_ok |
| 3 | same | same | same | 0 | 1900 | no | completed_ok |

Command: `C:\TOMWare\pin\pin.exe -- TestAntiDebug.exe`. Stderr empty; stdout oracle OK / PEB fields 0. Classification: technically valid on this launcher; omitted from the 9,000 by design. **Not incompatible.** Host StartServer is not this table. `campaign.json` `pin_condition_valid=false` is unchanged.

---

## VI-C Functional validation — REPLACE the Module32 denial

DELETE: “in particular, the absence of monitored modules in the baseline does not provide a positive control for their concealment.”

REPLACE with:

The five oracles assessed debugging, enumeration, the environment, memory comparisons, and timing. Those results are not evidence that corpus binaries performed the same checks. ProcessEnum includes a Module32 positive control on a dummy `%TEMP%\pinvm.dll` copy of `version.dll` (hidden under `-dp` and `-da`; `kernel32.dll` remained visible; Table 21). Combined activation was smoke-tested once per oracle (`da_n10.csv`; the filename does not mean ten repetitions; Table 22). InstMemcmpMask family controls cover `memcmp`, `_memicmp`, and `RtlCompareMemory`; `_memicmp_l` faulted on the campaign DLL; several comparison exports were not exercised (Table 23).

---

## VI-D Operational outcomes — 6,517 and SkewMask diagnostic

Table 19 includes all 9,000 attempts. The collector’s previous label `crash_exit` was corrected to termination with unavailable exit code. In the 9,000 JSON records, 6,517 rows were stored as `exception_crash` with a null `exit_code` and `exception_code=0x`. After `Start-Process` with redirected streams, Windows PowerShell 5.1 can leave `Process.ExitCode` unpopulated; a null compared with `< 0` was treated as a crash. True crashes with a known exit code in those 9,000 records: 0. The original JSON files were not rewritten. Collector v2.1 (`Get-SafeProcessExitCode` in `Invoke-SingleRun.ps1`) applies only to later campaigns. A success rate is not computed from the 6,517 rows.

Among persistent executables, observation-window attainment at 60 s increased from 21.2% with TMW0 to 55.2% with SkewMask and 60.2% with all modules. Greater observation-window attainment does not demonstrate equivalent progress or the recovery of malicious behavior.

The TMW0 versus TMW_DO corpus contrast uses 2,000 attempts (1,000 per condition), not 9,000. Table 25 is the N=3 process-tree diagnostic `access_r43d_process_tree` (all 27 attempts kept; no cherry-pick). Same a-priori SHAs: BEN_28, BEN_46, BEN_47. Modes Native / TMW0 (`-q`) / TMW_DO (`-do -q`). Snapshot `tomware_go`, DLL `4BBC6270`, elevated session, 50 ms sampling, launcher `C:\TOMWare\pin\pin.exe` SHA-256 `920A730A…0BB819` (`pin_sha256_matches_campaign=true`). Preserved and **not** Table 25: `access_r43` (`tree_error`), `access_r43b` (N=1; BEN_47 Pin 740), `access_r43c` (launcher was `intel64\bin\pin.exe` `FBA632E4`). Native 9/9 exited `−1073741511` (`STATUS_ENTRYPOINT_NOT_FOUND`) with no named last dump. TMW0 9/9 exited the same code in 1.4–2.9 s; last dump named on 5/9 (three `pin.exe` + sample + two `conhost.exe`). TMW_DO 9/9 `STILL_ALIVE_AT_WINDOW` at 60.2 s with that named tree. `behavioral_progress_observed=false` on all 27. `identified=false`. Persistence is wait/state, not recovered application behaviour. Full 27-row table: `TABELAS_25_26_27_R43D.md`.

**Table 25 (summary; all 27 rows in `TABELAS_25_26_27_R43D.md`).** `access_r43d_process_tree`, N=3, launcher `920A730A`.

| Sample | Native | TMW0 | TMW_DO |
|---|---|---|---|
| BEN_28 | 3/3 EXITED `−1073741511` (median 266 ms) | 3/3 EXITED `−1073741511` (median 1875 ms); named last 2/3 | 3/3 STILL_ALIVE ~60250 ms; named last 3/3 |
| BEN_46 | 3/3 EXITED `−1073741511` (median 188 ms) | 3/3 EXITED `−1073741511` (median 1375 ms); named last 2/3 | 3/3 STILL_ALIVE ~60297 ms; named last 3/3 |
| BEN_47 | 3/3 EXITED `−1073741511` (median 203 ms) | 3/3 EXITED `−1073741511` (median 1672 ms); named last 1/3 | 3/3 STILL_ALIVE ~60172 ms; named last 3/3 |

**Table 26 (N=3 trees).** Median elapsed and observed range. n=3 is too small for a bootstrap 95% CI. Corpus NAT/EMPTY/TMW0 CIs remain in `nat_empty_tmw0_table.csv`.

---

## VI-E Resource filters (already in CFD80; keep exact n)

Windows 120 s / 60 s and N=10 per cell were fixed before the 9,000 attempts. The resource-contrast filter is post hoc and is not in `experiment.config.json`. There were 98 eligible pairs per countermeasure for duration. CPU and memory had 98 pairs, except SanitizePinEnvVars, which had 97. MAL_33 and MAL_37 did not provide eligible measurements; for SanitizePinEnvVars, BEN_32 also did not provide CPU and memory measurements. Intervals are exploratory.

---

## VII-A — REPLACE the Module32 denial

DELETE: “ProcessEnum hid the monitored process entries; the absence of target modules in the baseline prevents confirmation of their filtering through Module32.”

REPLACE with:

ProcessEnum hid the `pin.exe` process entries on the Tool Help path that the process oracle exercised, and hid the dummy `pinvm.dll` fixture on the Module32 path (Table 21). The fixture is not the real Pin module. `GetModuleHandleA`/`W` and native `NtQuerySystemInformation` remain without individual validation.

---

## VII-D / VIII — remaining experimental limitations (do not mark resolved)

The following remain only partially addressed because no new experiments were run:

1. API traces and code coverage.
2. Per-binary hook-invocation counters (disabled in the 9,000).
3. Full temporal coherence (concurrent, nested, and alertable waits; cross-source consistency).
4. A malware case with identified check, branch, matching knob, and recovered hashed behavior.
5. Experimental comparison with Arancino, COBAI, or Peekaboo.

NAT and EMPTY are baselines in Table 19 and Table 26. The 9,000 attempts still omit Pin without a Pintool; Table 27 reports the isolated later probe. No experimental ranking versus Arancino is claimed.

---

## Campaigns remain separate

IEEE Access: 100 PE × 9 × 10 = 9,000; windows 120 s (short-lived) and 60 s (persistent). JCVHT: 31 PE, 10 s, 3,100. Do not share cells, hashes, or wait-table numbers across the two papers.
