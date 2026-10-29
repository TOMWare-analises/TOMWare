# Response to Reviewers — Access-2026-38745

**Manuscript:** Mitigating Evasive Techniques Against Dynamic Binary Instrumentation with Modular Countermeasures  
**Journal:** IEEE Access  
For each comment: reviewer comment; authors’ response; experiment or analysis; numeric result; change made; section / table / supplement; remaining limitation.

The 31-binary / 3,100-launch / 10 s campaign is not used below. All corpus numbers are 100 PE × 9 × 10 = 9,000.

---

## Reviewer 1

### R1.1 AntiDebug unmatched (`-gdb` versus `-dd`)

- **Comment.** Baseline and treatment used different debugger configurations.
- **Response.** We agree. The pair was rematched.
- **Experiment.** Three runs `-gdb -q` and three runs `-gdb -dd -q` on `TestAntiDebug.exe` (`antidebug_n3.csv`).
- **Result.** Baseline: IsDebuggerPresent / PEB.BeingDebugged / PEB.NtGlobalFlag = 1 (3/3). Treatment: all 0 (3/3). `-gdb` is a PEB stimulus, not an attached debugger.
- **Change.** Table of the matched pair; claim scoped to those PEB fields.
- **Location.** Functional AntiDebug table; Methods.
- **Limitation.** Other debug APIs were not the stimulus.

### R1.2 SkewMask selection bias (9/31)

- **Comment.** Re-executing failures biased the timing result.
- **Response.** We agree. The protocol is now fixed N=30 with all attempts retained.
- **Experiment.** `TestOverhead.exe`, arms TMW0 / GO / GO_DO (`matched_timing_n30.csv`).
- **Result.** TMW0 30/30 below 3000 (median 2433.285); GO 11/30 (3083.210); GO_DO 30/30 (2104.770).
- **Change.** Abstract and timing table use 11/30 versus 30/30. 9/31 removed.
- **Location.** Abstract; timing table.
- **Limitation.** This is oracle compensation, not malware efficacy. `SkewMask.cpp` was not changed.

### R1.3 No Arancino bake-off

- **Comment.** Modular value versus an integrated layer remains an assertion without a benchmark.
- **Response.** A direct benchmark was not performed and is not claimed.
- **Analysis.** Public Arancino: Pin 2.14, VS2010, 32-bit only. This work: Pin 3.28, 100/100 x64 (`BLOQUEIO.md`).
- **Result.** No paired numeric comparison exists.
- **Change.** Architectural table only; no ranking.
- **Location.** Related work; Conclusion; Future work.
- **Limitation.** A shared 32-bit protocol remains future work.

### R1.4 Small undocumented malware set

- **Comment.** Fourteen unclassified samples.
- **Response.** RQ2 now uses the 100-row manifesto.
- **Analysis.** `experiment/corpus/corpus.csv`.
- **Result.** 50+50, 25+25 per profile, 100/100 x64, SHA-256, source, date 2026-10-14. `Trojan_Bazaar` / `Backdoor_Bazaar` are coarse labels. `targeted_evasion=unverified`.
- **Change.** Corpus table plus path to `corpus.csv`.
- **Location.** Methods; supplement/repository.
- **Limitation.** Packer/protector unknown on malware. No claim that samples used the five checks.

### R1.5 Medians without CI; −87.2% as gain

- **Comment.** Large resource drops need uncertainty and a behavioral reading.
- **Response.** −87.2 / −38.5 are not in this revision. Persistence under `-do` is state/wait.
- **Experiment.** 9,000 attempts; bootstrap 2,000, seed 705851366; Wilson intervals; R4.3 diagnostic on BEN_28/46/47.
- **Result.** Benign persistent survival TMW0 24/250 (9.6%) → TMW_DO 132/250 (52.8%). R4.3: NAT/TMW0 exit `−1073741511`; TMW_DO Pin tree ~61 s.
- **Change.** Absolute paired deltas; −87.2 deleted; R4.3 paragraph added.
- **Location.** Resource tables; diagnostic subsection.
- **Limitation.** No API traces of persistents. CPU zeros unvalidated (item 6).

### R1.6 Narrow surface versus title

- **Comment.** Alternate APIs bypass the modules.
- **Response.** Agreed. The title denotes selected monitored interfaces.
- **Analysis.** Implementation inventory versus oracles.
- **Result.** `NtQuerySystemInformation`, `RDTSC`, and several comparison exports were not individually validated.
- **Change.** Conclusion scoped; unimplemented/unvalidated list explicit.
- **Location.** Conclusion; Limitations.
- **Limitation.** Adaptive detection remains possible.

---

## Reviewer 2

### R2.1 Matched AntiDebug

Same as R1.1.

### R2.2 Fixed-N timing, distributions, CIs

Same oracle as R1.2. Corpus `TMW_DO` retains all 1,000 outcomes. No binary “SkewMask is effective” verdict.

### R2.3 Native / empty / disabled / enabled baselines

- **Comment.** Incremental-only baselines hide Pin cost.
- **Response.** Nine conditions are reported. Two contrasts are separated (items 7–8).
- **Experiment.** 1,000 attempts each: NAT, EMPTY, TMW0, five knobs, TMW_ALL. Pin-without-tool probe failed.
- **Result.** Short-lived benign median-of-medians wall-clock: NAT 0.26 s, EMPTY 1.48 s, TMW0 1.97 s.
- **Change.** Baseline ladder table; EMPTY ≠ bare Pin engine.
- **Location.** Methods; baseline table.
- **Limitation.** EMPTY still includes tool load.

### R2.4 Auditable corpus table

Same as R1.4. Path: `experiment/corpus/corpus.csv`.

### R2.5 Compare Arancino, COBAI, Peekaboo

Same as R1.3. COBAI and Peekaboo are absent from the repository; architectural table only.

### R2.6 Behavioral fidelity (API traces, coverage)

- **Comment.** Completion does not prove equivalent behavior.
- **Response.** We agree. Equivalence is not demonstrated (item 13).
- **Experiment.** External observer, 10 PE × 4 arms × 3 = 120 runs; TMW0 versus TMW_ALL.
- **Result.** 22/30 pairs matched on exit code and stdout hash; 8 disagreed (item 1).
- **Change.** Diagnostic table; language limited to observables.
- **Location.** Diagnostic subsection; Discussion.
- **Limitation.** No API/coverage/file/registry/network equivalence.

### R2.7 Weak compatibility criterion

- **Comment.** Alive-or-exited is too weak (old 155/155).
- **Response.** 155/155 removed. Outcome classes reported. 6,517 rows are unavailable exit codes, not crashes (item 5).
- **Analysis.** `completeness.json`, `outcomes_by_stratum.csv`, `campaign_audit_report.md`.
- **Result.** 6,517 unknown-exit; 1,355 window; 877 timeout; 251 launch_failed; true coded crash = 0.
- **Change.** Table 19-class outcomes; no success rate from the 6,517.
- **Location.** Operational tables; Methods.
- **Limitation.** Criterion remains operational.

### R2 extra Combined `-da`; malware used the five checks

- **Comment.** Need combined mode and proof of in-the-wild checks.
- **Response.** Combined mode exists as TMW_ALL (9,000) plus a five-oracle smoke test (item 3). The malware-check claim is **not** made (item 14).
- **Result.** `-da` oracles: 5/5 exit 0, one run each. `identified=false`.
- **Change.** Smoke-test table; negative statement on evasion use.
- **Limitation.** Smoke test ≠ corpus interaction study. No evasive chain.

---

## Reviewer 3

### R3.1 Repeat matched AntiDebug or mark unvalidated

Matched (R1.1). Not classified as unvalidated.

### R3.2 29% re-execution

That 29% (9/31) is the withdrawn protocol. Current: 0 re-executions, 11/30 versus 30/30.

### R3.3 Uncertainty / descriptive results

Wilson and bootstrap intervals are reported and labeled exploratory. No p-values. Resource CIs that contain zero are not equivalence. CPU is descriptive only (item 6).

### R3.4 Related-systems table

Kept. No experimental ranking.

### R3.5 Language and formatting

Portuguese evaluation pages are replaced by the English inserts. Decimal points (not locale commas) in tables. Full IEEE-formatted compile is Overleaf (item 19).

---

## Reviewer 4

### R4.1 Run matched AntiDebug

Done (R1.1). Removed from future work.

### R4.2 Report every timing attempt

Done (R1.2). Abstract states 11/30 versus 30/30, N=30, all retained.

### R4.3 Explain −87.2 / −38.5 or test behavior

- **Comment.** Large resource deltas may be truncated or altered execution.
- **Response.** Those percentages are withdrawn. The 60 s campaign and R4.3 are the test (item 4).
- **Experiment.** 9,000 TMW0 versus TMW_DO; plus N=1 NAT/TMW0/TMW_DO on BEN_28/46/47.
- **Result.** TMW_DO fills the window; R4.3 NAT/TMW0 `STATUS_ENTRYPOINT_NOT_FOUND`; TMW_DO Pin tree ~61 s; `identified=false`.
- **Change.** Persistence = state/wait. −87.2 / −38.5 deleted.
- **Location.** Resource discussion; `access_r43` supplement.
- **Limitation.** No application-progress evidence.

### R4.4 Metric-validity rule

- **Comment.** Wall-clock versus N/A was not reconstructable.
- **Response.** Observation windows (120 s / 60 s) and N=10 were a priori. The resource-pair filter was **post hoc** and was **not** in `experiment.config.json` (item 10). The previous draft must not call it prospective.
- **Analysis.** 98 pairs retained; MAL_33 and MAL_37 excluded from resource contrasts only.
- **Result.** `n_pairs` is not always 25.
- **Change.** Methods states the filter is retrospective; intervals exploratory.
- **Location.** Methods.
- **Limitation.** Retrospective selection of resource rows.

### R4 extra Native baseline; Pin without tool

NAT and EMPTY are in the 9,000. Pin without a tool was unsupported. EMPTY is the smallest Pin-hosted reference, not engine-only cost (items 7–8).

---

## Reviewer 5

### R5.1 Clarify AntiDebug configurations

Matched (R1.1). PEB scope only.

### R5.2 Moderate behavioral-preservation claims

Abstract and conclusion deny equivalence. 22/30 is limited observable agreement (item 1).

### R5.3 Performance may reflect execution state

Adopted. SkewMask wall-clock increase and R4.3 are the leading examples. CPU zeros are not savings (item 6).

### R5.4 More DBI-evasion references

Optional. No unread citations added.

### R5.5 Conclusions within oracles and corpus

Rewritten (item 17): PEB-only AntiDebug; oracle-only SkewMask; 22/30 observables; no progress; no recovered malware behavior; no transparency; no Arancino experiment.

---

## Reviewer 6

### R6.1 AntiDebug configurations differ

Matched (R1.1).

### R6.2 Timing re-execution

Fixed N=30 (R1.2).

### R6.3 Compatibility is not equivalence

155/155 removed. Equivalence not demonstrated (item 13). No evasive case (item 14).

### R6.4 No native baseline; only medians

NAT + EMPTY + Wilson/bootstrap. CPU remains descriptive.

### R6.5 Novelty versus existing frameworks

Architectural comparison only. No Arancino superiority (item 15).

---

## Reproducibility (item 16)

Stamped after the evidence commit (see `REPRODUCIBILITY.txt`). Required fields: full commit, DLL SHA-256, Pin 3.28.98749, snapshot `tomware_go`, seed 705851366, `corpus.csv`, `Invoke-SingleRun.ps1` v2.1, `Run-AccessR43.ps1`, `experiment/results/oracles/access_r43/`, `fidelity_by_run.csv`, `da_n10.csv`, `module32_fixture.csv`.
