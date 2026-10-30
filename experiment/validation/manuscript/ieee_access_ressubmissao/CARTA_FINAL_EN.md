# Response to Reviewers — Access-2026-38745 (final)

**Manuscript:** Mitigating Evasive Techniques Against Dynamic Binary Instrumentation with Modular Countermeasures  
**Base PDF:** English revision SHA-256 `CFD80F0D0EE9…` (not the older `5CBC8E96…` file).  
For every comment: reviewer comment; authors’ response; experiment or analysis; numeric result; change made; section / table / supplement; remaining limitation.

Corpus numbers below are from the 100 PE × 9 × 10 = 9,000 campaign. The JCVHT 31 PE / 3,100 / 10 s campaign is not used.

**Reproducibility (single citation):** git `665aebba7e555ecafbdcfd33f18c076cef39526d` (`REPRODUCIBILITY.txt`). Pin 3.28.98749; campaign DLL `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`; snapshot `tomware_go`; seed 705851366. Base PDF SHA-256 `CFD80F0D0EE964CDAC490A55152454C219F2EB63B86A46CDCB220C0E766B3000`. Older hashes `e382a6c` / `58ea738` / `cf735e1` are superseded.

**Declared remaining gaps (not marked resolved):** API traces and code coverage; per-binary hook counters (disabled in the 9,000); full temporal coherence; a malware case with identified check, branch, knob, and recovered behavior; experimental comparison with Arancino, COBAI, or Peekaboo.

---

## Reviewer 1

### R1.1 AntiDebug unmatched (`-gdb` versus `-dd`)

- **Comment.** Baseline and treatment used different debugger configurations.
- **Response.** We agree. The pair was rematched with the same simulated stimulus.
- **Experiment.** Three runs of `pin -t TOMWare.dll -gdb -q -- TestAntiDebug.exe` and three runs of `-gdb -dd -q` (`antidebug_n3.csv`).
- **Result.** Baseline: IsDebuggerPresent, PEB.BeingDebugged, and PEB.NtGlobalFlag = 1 (3/3). Treatment: all 0 (3/3). `-gdb` is a PEB oracle, not an attached debugger.
- **Change.** Table 3 reports the matched pair. Combined-mode AntiDebug is one additional row in Table 22 (`-gdb -da -q`, exit 0).
- **Location.** Section V-A; Table 3; Table 22.
- **Limitation.** CheckRemoteDebuggerPresent, ProcessDebugPort, and ProcessDebugObjectHandle were 0 in every arm and were not the stimulus.

### R1.2 SkewMask selection bias (9/31)

- **Comment.** Re-executing failures biased the timing result.
- **Response.** We agree. The current oracle uses a pre-fixed $N=30$ and retains every attempt.
- **Experiment.** `TestOverhead.exe`; arms TMW0 (`-q`), GO (`-go -q`), GO_DO (`-go -do -q`); `matched_timing_n30.csv`.
- **Result.** TMW0 30/30 below 3000 (median 2433.285); GO 11/30 (3083.210); GO_DO 30/30 (2104.770).
- **Change.** Abstract and Table 15 use 11/30 versus 30/30. The 9/31 protocol is withdrawn.
- **Location.** Abstract; Section V-E; Table 15.
- **Limitation.** This is compensation of the specific oracle, not a Pin-concealment rate and not malware efficacy. `SkewMask.cpp` was not modified.

### R1.3 No experimental benchmark against Arancino

- **Comment.** Without a direct comparison, modular value versus an integrated layer remains an assertion.
- **Response.** No bake-off was performed. We do not claim superiority.
- **Analysis.** Public Arancino (necst/arancino) targets Pin 2.14, Visual Studio 2010, and 32-bit binaries. This campaign uses Pin 3.28 and a 100/100 x64 corpus (`BLOQUEIO.md`).
- **Result.** No paired numeric comparison exists.
- **Change.** Table 1 remains architectural. Future work states a shared 32-bit protocol.
- **Location.** Section II; Table 1; Section VIII.
- **Limitation.** Experimental comparison with Arancino, COBAI, and Peekaboo remains open.

### R1.4 Small undocumented malware set

- **Comment.** Fourteen unclassified samples versus the large-scale studies cited in the introduction.
- **Response.** RQ2 uses a 100-row manifesto.
- **Analysis.** `experiment/corpus/corpus.csv`: SHA-256, source, acquisition date 2026-10-14, class, coarse type, x64, profile, packer/protector, `targeted_evasion`.
- **Result.** 50 benign + 50 malicious; 25+25 short-lived/persistent per class. `Trojan_Bazaar` and `Backdoor_Bazaar` are coarse MalwareBazaar labels, not VirusTotal families. Packer/protector is `unknown` on malware. `targeted_evasion=unverified` for all 50 malicious binaries.
- **Change.** Table 18; path to `corpus.csv` in Section VI-B.
- **Location.** Section VI-B; Table 18; repository supplement.
- **Limitation.** No claim that corpus malware executed the five hooked checks.

### R1.5 Medians without CI; −87.2% as gain

- **Comment.** Large resource drops need uncertainty and a behavioral reading.
- **Response.** −87.2% / −38.5% are not in this English revision. Persistence under `-do` is treated as state or wait.
- **Experiment.** Table 16/19 corpus contrast TMW0 versus TMW_DO: **2,000 attempts (1,000 per condition)**, not 9,000. Resource pairs: 98 for duration (MAL_33 and MAL_37 excluded from those contrasts only). Additional diagnostic Table 25: BEN_28, BEN_46, BEN_47, $N=1$.
- **Result.** Benign persistent window-survival TMW0 9.6% → TMW_DO 52.8% (Table 19 class counts). Table 25: NAT and TMW0 exit `−1073741511` (`STATUS_ENTRYPOINT_NOT_FOUND`); TMW_DO Pin tree still alive ~61 s; `identified=false`.
- **Change.** Absolute paired deltas in Tables 17 and 20; Table 25 added; −87.2 deleted.
- **Location.** Section V-E; Section VI-D; Tables 17, 19, 20, 25.
- **Limitation.** No API traces of persistents. Recorded CPU zeros are descriptive only.

### R1.6 Narrow interception surface versus the title

- **Comment.** Alternate APIs (e.g. `NtQuerySystemInformation`, `RDTSC`) bypass the modules.
- **Response.** Agreed. The title denotes selected monitored interfaces.
- **Analysis.** Implementation list versus oracles (Table 23 unexercised exports; Section V-B native queries).
- **Result.** `NtQuerySystemInformation`, `RDTSC`, `GetModuleHandle` as a full matrix, `RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `wmemcmp_s`, and `bcmp` were not individually validated.
- **Change.** Conclusion scoped; Table 23 states unexercised routines.
- **Location.** Section VII-A; Section VIII; Table 23.
- **Limitation.** Adaptive detection remains possible.

---

## Reviewer 2

### R2.1 Share the matched AntiDebug rerun

- **Comment.** Provide a matched `-gdb` versus `-gdb -dd` comparison.
- **Response.** The pair was rematched with the same simulated stimulus in both arms.
- **Experiment.** Three runs of `-gdb -q` and three runs of `-gdb -dd -q` on `TestAntiDebug.exe` (`antidebug_n3.csv`).
- **Result.** Baseline PEB / IsDebuggerPresent = 1 (3/3). Treatment = 0 (3/3).
- **Change.** Table 3.
- **Location.** Section V-A; Table 3.
- **Limitation.** `-gdb` is not an attached debugger. Other debug APIs were not the stimulus.

### R2.2 Redesign SkewMask: fixed repetitions, retain all results, distributions and CIs

- **Comment.** Predefine $N$, retain failures, report distributions and intervals.
- **Response.** The oracle uses $N=30$ with all 90 attempts retained. Corpus TMW_DO retains all 1,000 outcomes.
- **Experiment.** `matched_timing_n30.csv`; corpus Table 16 (1,000 TMW_DO attempts).
- **Result.** GO 11/30 below 3000; GO_DO 30/30. No binary “effective” verdict.
- **Change.** Table 15; 9/31 removed.
- **Location.** Section V-E; Table 15; Table 16.
- **Limitation.** Oracle compensation is not a corpus evasion rate. Concurrent-wait timeouts remain inconclusive.

### R2.3 Native, empty-tool, disabled-module, and enabled-module baselines

- **Comment.** Incremental-only baselines hide the cost of Pin relative to native execution.
- **Response.** Nine conditions are reported. Two contrasts are separated: total instrumentation cost (NAT versus EMPTY or TMW0) and incremental countermeasure effect (TMW0 versus the enabled module).
- **Experiment.** 1,000 attempts each: NAT, EMPTY, TMW0, five knobs, TMW_ALL. Table 26 reports short-lived benign medians. Table 27 reports the isolated Pin-without-tool probe.
- **Result.** Short-lived benign, n=25: NAT 0.260 s, EMPTY 1.485 s, TMW0 1.973 s (`nat_empty_tmw0_table.csv`). Paired EMPTY−NAT +1.166 s; TMW0−EMPTY +0.151 s. Guest Pin-without-tool (22 Oct): exit 0, empty stderr, oracle stdout; campaign omitted PIN. Host probe (30 Oct): StartServer assertion in 718 ms, conclusion not_supported_by_engine; different pin.exe SHA-256.
- **Change.** Table 26 (four strata + paired deltas + missing counts) and Table 27 (guest and host probes). TMW0 versus a module is not described as the total Pin cost.
- **Location.** Section VI-B; Tables 19, 26, 27; `nat_empty_tmw0_table.csv`; `pin_bare_probe_host/`.
- **Limitation.** EMPTY still includes tool load and injection. The 9,000 attempts have no PIN-without-tool cells. Host Pin is not the guest campaign binary.

### R2.4 Auditable corpus table

- **Comment.** SHA-256, source, family, packer, architecture, profile, targeted evasion.
- **Response.** Those columns are in the manifesto.
- **Analysis.** `experiment/corpus/corpus.csv`, 100 rows, `included=true`.
- **Result.** Coarse families only; `targeted_evasion=unverified` for malware; packer unknown on malware.
- **Change.** Table 18; path stated in Section VI-B.
- **Location.** Section VI-B; Table 18; repository.
- **Limitation.** No VirusTotal family names invented.

### R2.5 Strengthen comparison with Arancino, COBAI, Peekaboo

- **Comment.** Compare experimentally with related defensive systems.
- **Response.** No experimental ranking was produced.
- **Analysis.** Table 1 architectural comparison. Arancino is Pin 2.14 / 32-bit; COBAI and Peekaboo are absent from the repository as runnable tools on this protocol.
- **Result.** No bake-off numbers.
- **Change.** Table 1 retained; Section VIII lists a shared 32-bit protocol as future work.
- **Location.** Section II; Table 1; Section VIII.
- **Limitation.** Experimental comparison remains open.

### R2.6 Behavioral-fidelity validation (API traces, coverage, process activity)

- **Comment.** Completion or remaining active does not prove equivalent behavior.
- **Response.** We agree. Equivalence is not demonstrated.
- **Experiment.** External observer, 10 PE × NAT/EMPTY/TMW0/TMW_ALL × 3 = 120 runs; TMW0 versus TMW_ALL yields 30 pairs (`fidelity_by_run.csv`).
- **Result.** 22/30 pairs matched on exit code and stdout SHA-256; 8 disagreed (Table 24).
- **Change.** The 22/30 result is no longer Introduction-only; method, samples, three repetitions, criterion, and the eight disagreements are in Section VI and Table 24. Hook-invocation counters were **not collected** in the 9,000 JSON (`module_counters` off).
- **Location.** Section VI; Table 24; Section VII-B.
- **Limitation.** No API traces, code coverage, or file/registry/network equivalence.

### R2.7 Compatibility is too weakly defined

- **Comment.** Process completion or remaining active does not prove behavioral equivalence (old 155/155).
- **Response.** 155/155 is withdrawn. Outcome classes are reported. The 6,517 rows are unavailable exit codes, not crashes.
- **Analysis.** `completeness.json`; Table 19; collector audit in Section VI-D.
- **Result.** 6,517 termination-with-unavailable-exit-code; 1,355 window; 877 timeout; 251 launch_failed; true coded crash in the 9,000 = 0. Original JSON not rewritten. Collector v2.1 is prospective only.
- **Change.** Table 19 wording; no success rate from the 6,517.
- **Location.** Section VI-D; Table 19.
- **Limitation.** The criterion remains operational.

### R2 extra Combined `-da`; proof malware used the five checks

- **Comment.** Combined mode was missing; no proof the malware used the five techniques.
- **Response.** Combined mode is TMW_ALL in the 9,000 (Table 19) plus a five-oracle smoke test. ProcessEnum now includes a Module32 positive control (Table 21). We do not claim corpus malware used the five checks.
- **Experiment.** `da_n10.csv`: five rows, one execution per oracle (the filename is campaign id `t2_n10_v7b`, not ten `-da` repetitions). `module32_fixture.csv`: dummy `%TEMP%\pinvm.dll` copy of `version.dll`.
- **Result.** All five oracles exit 0 (Table 22). Table 21: fixture visible under Native/TMW0 and hidden under `-dp`/`-da`; `kernel32.dll` remained visible. `identified=false`; `targeted_evasion=unverified`.
- **Change.** Table 21; Table 22; negative statement in Section VII-B.
- **Location.** Section V-B; Section VI-C; Tables 21 and 22; Section VII-B.
- **Limitation.** Smoke test ≠ corpus interaction study. The fixture is not the real Pin module. No check–branch–recovered-behavior malware case.

---

## Reviewer 3

### R3.1 Repeat matched AntiDebug or classify the module as unvalidated

- **Comment.** Repeat the matched comparison or mark AntiDebug unvalidated.
- **Response.** The matched comparison was run; AntiDebug is not classified as unvalidated, but the claim is limited to the PEB fields exercised.
- **Experiment.** `antidebug_n3.csv`, 3+3.
- **Result.** Baseline 3/3 positive; treatment 3/3 zero (Table 3).
- **Change.** Table 3; Section V-A scope sentence.
- **Location.** Section V-A; Table 3.
- **Limitation.** Not a real attached debugger.

### R3.2 Clarify the 29% re-execution rate

- **Comment.** The 29% (9/31) re-execution rate and selection bias.
- **Response.** That 29% describes the withdrawn protocol only.
- **Experiment.** Fixed $N=30$, 0 re-executions, 90/90 retained.
- **Result.** 11/30 versus 30/30 (Table 15).
- **Change.** 29% and 9/31 removed from the abstract and Table 15.
- **Location.** Abstract; Section V-E; Table 15.
- **Limitation.** Oracle-specific.

### R3.3 Add confidence intervals or emphasize that results are descriptive

- **Comment.** Medians need uncertainty or an explicitly descriptive reading.
- **Response.** Rates use Wilson 95% CIs. Paired medians use bootstrap 2,000, seed 705851366. Resource intervals are labeled exploratory. CPU is descriptive; zeros do not mean no consumption.
- **Analysis.** Tables 5, 8, 11, 14, 17, 20. Duration pairs $n=98$; SanitizePinEnvVars CPU/memory $n=97$ (BEN_32).
- **Result.** Several CIs include zero and are not treated as equivalence.
- **Change.** Methods (Section VI-E) states the resource filter is post hoc.
- **Location.** Section VI-E; resource tables.
- **Limitation.** No $p$-values. Post hoc resource rows.

### R3.4 Concise related-systems table

- **Comment.** Add a related-systems table.
- **Response.** The table is in the English revision.
- **Analysis.** Table 1.
- **Result.** Architectural comparison only.
- **Change.** None beyond retaining Table 1.
- **Location.** Section II; Table 1.
- **Limitation.** No experimental ranking.

### R3.5 Language and formatting pass

- **Comment.** Language and formatting.
- **Response.** This revision uses the English CFD80 PDF as the base. Portuguese evaluation pages from the older 5CBC file are not the source. Inconsistent screenshot captures were removed or replaced by numbered tables (Tables 3, 6, 12, 21–27). Decimal points are used in tables.
- **Change.** Base PDF swap; table replacements.
- **Location.** Throughout; Tables 21–27.
- **Limitation.** Overleaf must compile the authors’ `.tex` with these tables; this repository supplies `Access-2026-38745_REVISION_TABLES.tex`.

---

## Reviewer 4

### R4.1 Run the matched AntiDebug experiment; do not list it as future work

- **Comment.** Run the matched experiment; remove it from future work.
- **Response.** It was run and is not listed as future work.
- **Experiment.** `antidebug_n3.csv`.
- **Result.** 3/3 versus 3/3 on the PEB fields (Table 3).
- **Change.** Table 3; future-work list in Section VIII.
- **Location.** Section V-A; Table 3; Section VIII.
- **Limitation.** PEB stimulus only.

### R4.2 Report all timing-oracle outcomes; compensation rate; fix the abstract

- **Comment.** Report every attempt and a compensation rate; fix the abstract.
- **Response.** All 90 attempts are retained. The abstract reports 11/30 versus 30/30.
- **Experiment.** Table 15.
- **Result.** GO 11/30; GO_DO 30/30; TMW0 30/30.
- **Change.** Abstract; Table 15.
- **Location.** Abstract; Section V-E; Table 15.
- **Limitation.** Not a general Pin-hiding rate.

### R4.3 Explain −87.2% / −38.5% or test behavior

- **Comment.** Large SkewMask resource deltas may reflect truncated or altered execution.
- **Response.** Those percentages are withdrawn. The 60 s corpus contrast and Table 25 are the test.
- **Experiment.** Table 16/19: **1,000 TMW0 + 1,000 TMW_DO = 2,000 attempts**. Table 25: BEN_28, BEN_46, BEN_47, NAT / TMW0 / TMW_DO, $N=1$, 60 s.
- **Result.** TMW_DO fills the window in the corpus medians. Table 25: native/TMW0 `STATUS_ENTRYPOINT_NOT_FOUND`; TMW_DO Pin tree ~61 s; empty stdout/stderr; `identified=false`.
- **Change.** Tables 17, 20, 25; −87.2 / −38.5 absent.
- **Location.** Section V-E; Section VI-D; Tables 17, 19, 25.
- **Limitation.** No application-progress evidence.

### R4.4 State the metric-validity rule

- **Comment.** Wall-clock versus N/A was not reconstructable.
- **Response.** Windows 120 s / 60 s and $N=10$ were fixed before the 9,000. The resource-pair filter (`sample_count>0`, finite memory) is **post hoc** and is **not** in `experiment.config.json`.
- **Analysis.** 98 duration pairs; SanitizePinEnvVars CPU/memory 97 pairs (MAL_33, MAL_37, and for that module BEN_32).
- **Result.** Effective $n$ is not always 25. Intervals are exploratory.
- **Change.** Section VI-E states the filter is retrospective.
- **Location.** Section VI-E.
- **Limitation.** Retrospective selection of resource rows.

### R4 extra Native baseline; internals; hook counts; `-da`

- **Comment.** Native baseline; figure internals; hook counts; combined `-da`.
- **Response.** NAT and EMPTY are in Table 19. Inconsistent screenshot captures were removed and replaced by tables. Per-binary hook counters were not collected in the 9,000 (`-mc` off). Combined `-da` is Table 22 (oracles) and the TMW_ALL column of Table 19 (corpus). Module32 is Table 21.
- **Experiment.** Tables 19, 21, 22, 26, 27.
- **Result.** Table 26 medians as in R2.3. Table 21: dummy `pinvm.dll` hidden under `-dp` and `-da`. Table 22: 5/5 exit 0, one run each.
- **Change.** Tables 21, 22, 26, 27; no screenshot panels.
- **Location.** Section V-B; Section VI; Tables 19, 21, 22, 26, 27.
- **Limitation.** No per-binary hook counts in the 9,000.

---

## Reviewer 5

### R5.1 Clarify or match AntiDebug debugger configurations

- **Comment.** Debugger configurations differed.
- **Response.** The evaluation now uses the same `-gdb` stimulus in baseline and treatment.
- **Experiment.** `antidebug_n3.csv`.
- **Result.** 3/3 positive versus 3/3 zero on the PEB fields (Table 3).
- **Change.** Table 3.
- **Location.** Section V-A; Table 3.
- **Limitation.** Not an attached debugger.

### R5.2 Moderate behavioral-preservation claims

- **Comment.** Compatibility does not establish equivalence of system calls, control flow, or external effects.
- **Response.** We agree. The abstract and Section VII-B deny equivalence.
- **Experiment.** Table 24 (22/30 observables); Table 19 operational classes.
- **Result.** 22/30 is limited agreement of exit code and stdout hash.
- **Change.** Language in Abstract, Section VI, Section VII-B.
- **Location.** Abstract; Table 24; Section VII-B.
- **Limitation.** API traces and coverage remain absent.

### R5.3 Performance results are descriptive and may reflect execution-state changes

- **Comment.** Performance numbers may reflect state changes, not efficiency.
- **Response.** Adopted. SkewMask wall-clock increase and Table 25 are the leading examples. CPU zeros are not savings.
- **Experiment.** Tables 17, 20, 25.
- **Result.** TMW_DO stretches wall-clock toward 60 s; Table 25 shows Pin-tree persistence after native entrypoint failure.
- **Change.** Section V-E and VII-B wording.
- **Location.** Sections V-E, VI-D, VII-B; Tables 17, 25.
- **Limitation.** No progress milestones.

### R5.4 Strengthen the reference list with recent DBI-evasion studies

- **Comment.** Add recent work on DBI evasion, anti-debugging/anti-instrumentation, and timing or memory countermeasures.
- **Response.** The English revision already incorporates recent, directly relevant studies; we did not add unread citations.
- **Analysis.** The reference list includes Park and Park, *Electronics*, 2024, on Windows DBI detection [6]; Padhy et al., *IEEE Access*, 2025, on threat-informed evasion [15]; Gaber et al., *JISA*, 2025, Peekaboo [18]; Norby et al., *IEEE Access*, 2025, on anti-debugging measurement [19]; and Zhao et al., 2025, LibIHT hardware-assisted analysis [21], together with D’Elia et al. SoK (2019) and conspicuous-artifact evaluation (2022) [9], [10].
- **Result.** Those works are cited in Sections I–II and in the related-systems discussion (Table 1).
- **Change.** No additional unread references. Table 1 and the bibliography of the CFD80 PDF are retained.
- **Location.** Section II; Table 1; References [6], [9], [10], [15], [18], [19], [21].
- **Limitation.** Citation does not substitute for an experimental bake-off.

### R5.5 Keep conclusions within the oracles and the evaluated corpus

- **Comment.** Do not generalize beyond the oracles and corpus.
- **Response.** Conclusions are restricted as requested.
- **Analysis.** Section VIII and the Abstract.
- **Result.** AntiDebug is PEB-only; SkewMask is the specific oracle; 22/30 is observable agreement; persistence is not progress; no recovered malware behavior; no universal transparency; no Arancino experiment.
- **Change.** Abstract and Section VIII.
- **Location.** Abstract; Section VIII.
- **Limitation.** The five gaps listed at the head of this letter.

---

## Reviewer 6

### R6.1 AntiDebug configurations differ

- **Comment.** Baseline and treatment used different debugging configurations.
- **Response.** The pair is now matched.
- **Experiment.** `antidebug_n3.csv`, 3+3.
- **Result.** Table 3: 3/3 versus 3/3 on the PEB fields.
- **Change.** Table 3.
- **Location.** Section V-A; Table 3.
- **Limitation.** Simulated PEB stimulus only.

### R6.2 Timing re-execution / selection bias

- **Comment.** Re-executing failures may introduce selection bias.
- **Response.** The current protocol does not re-execute failures.
- **Experiment.** $N=30$, 90/90 retained (`matched_timing_n30.csv`).
- **Result.** 11/30 versus 30/30 (Table 15).
- **Change.** Abstract; Table 15.
- **Location.** Abstract; Section V-E; Table 15.
- **Limitation.** Oracle-specific compensation.

### R6.3 Weak operational compatibility, especially for malware

- **Comment.** Compatibility does not demonstrate behavioral equivalence or transparency.
- **Response.** We agree. 155/155 is withdrawn. Equivalence is not demonstrated. No malware case with check–branch–recovered behavior exists.
- **Experiment.** Table 19; Table 24; `identify_summary.csv` (`identified=false`).
- **Result.** 6,517 unavailable exit codes; 22/30 observables; no hashed extra artifact chain.
- **Change.** Table 19; Table 24; Section VII-B.
- **Location.** Sections VI-D, VII-B; Tables 19, 24.
- **Limitation.** The malware-case gap remains.

### R6.4 No native baseline; only medians

- **Comment.** No native baseline; statistics limited to medians.
- **Response.** NAT and EMPTY are in the 9,000. Wilson and bootstrap intervals are reported. Table 26 gives NAT / EMPTY / TMW0 medians for short-lived benign binaries.
- **Experiment.** Tables 19, 26, 27.
- **Result.** NAT 0.260 s, EMPTY 1.485 s, TMW0 1.973 s ($n=25$). CPU remains descriptive.
- **Change.** Tables 26 and 27.
- **Location.** Section VI-B; Tables 19, 26, 27.
- **Limitation.** Pin-without-tool is not a 9,000 arm.

### R6.5 Novelty versus existing DBI countermeasure frameworks

- **Comment.** Novelty versus Arancino and related frameworks needs experimental support.
- **Response.** Novelty is stated as modular evaluation and the nine-condition protocol, not as an experimental ranking.
- **Analysis.** Table 1; `BLOQUEIO.md`.
- **Result.** No bake-off.
- **Change.** Section VIII future work item on a shared 32-bit protocol.
- **Location.** Section II; Table 1; Section VIII.
- **Limitation.** Experimental comparison with Arancino, COBAI, and Peekaboo remains open.
