# Response to Reviewers

**Manuscript ID:** Access-2026-38745  
**Title:** Mitigating Evasive Techniques Against Dynamic Binary Instrumentation with Modular Countermeasures  
**Journal:** IEEE Access  
**Software tag:** TOMWare git tree; campaign `corpus_aligned_10k`, seed `705851366`, Intel Pin 3.28

We thank the Associate Editor and the six reviewers. IEEE Access allows one resubmission. For each comment we state (a) the concern, (b) our response, and (c) the Overleaf action.

**New evidence in this revision**

1. **Functional oracles (guest VM, 21 Oct 2026).** Matched AntiDebug; ProcessEnum / `-da`; environment; memcmp; Module32First/Next. Raw: `experiment/results/oracles/functional_oracles.csv`, `module32_waits.csv`.
2. **SkewMask timing oracle, fixed N=30, all attempts retained.** Arms TMW0 (`-q`), GO (`-go -q`), GO_DO (`-go -do -q`) on `TestOverhead.exe`. No outcome-selected re-execution. Compensation rate = share of attempts with ticks &lt; 3000. Raw: `matched_timing_n30.csv`, `matched_timing_summary.csv`.
3. **Corpus campaign, 21 Oct 2026.** 100 PE × 9 conditions × 10 repetitions = **9,000/9,000** JSON records. Ladder: NAT, EMPTY, TMW0, five single-module arms, TMW_ALL (`-da`). Windows fixed a priori: 120 s short-lived, 60 s persistent. Host revert every block. Processed tables: `experiment/results/campaign/corpus_aligned_10k/`.

The previous 31-binary / 3,100-launch / 10 s corpus **must be replaced** in Overleaf. Do not mix those cells with the 9,000-run tables.

---

## Reviewer 1

### R1.1 — AntiDebug was not functionally validated (unmatched `-gdb` vs `-dd`)

**(a) Concern.** The baseline used `-gdb` and the treatment used `-dd` without `-gdb`, so the disappearance of PEB indicators cannot be attributed to AntiDebug. Presenting AntiDebug as a core contribution overstated the validation.

**(b) Response.** We agree the original pair was invalid. We re-ran a **matched** oracle: `pin -t TOMWare.dll -gdb -q -- TestAntiDebug.exe` versus `pin -t TOMWare.dll -gdb -dd -q -- TestAntiDebug.exe` (same simulated-debugging stimulus). Guest records (21 Oct 2026): baseline reported `IsDebuggerPresent`, `PEB.BeingDebugged`, and `PEB.NtGlobalFlag`; treatment reported `OK - nenhuma anomalia`. This supports suppression of those two PEB fields under the simulated stimulus only. Corpus `-dd` runs are **not** used as functional proof that a sample queried the PEB.

**(c) Action.** Keep Figure 2 / Table 4 as the matched pair. Delete any “unvalidated / inconclusive / future work” wording for this comparison. Scope the claim to the two PEB fields.

### R1.2 — SkewMask timing evaluation was subject to selection bias

**(a) Concern.** Nine of 31 checks were re-executed until the score fell below the threshold. Retaining those pairs cannot support an unbiased detection probability.

**(b) Response.** We agree. We replaced that protocol with a **pre-fixed N=30** on `TestOverhead.exe`. Every attempt was kept (no re-execution). Threshold = 3,000 (unchanged).

| Arm | Knobs | N | Median ticks | Below threshold |
|-----|--------|---|--------------|-----------------|
| TMW0 | `-q` | 30 | 2,418 | 30/30 (100%) |
| GO (baseline) | `-go -q` | 30 | 3,079 | **11/30 (36.7%)** |
| GO_DO (treatment) | `-go -do -q` | 30 | 2,104 | **30/30 (100%)** |

Range GO: 2,722–3,845. Range GO_DO: 2,073–2,146. The old 9/31 figure must not appear in the abstract or Table 4. Separately, the corpus `TMW_DO` arm used ten pre-fixed repetitions and retained all 1,000 outcomes.

**(c) Action.** Abstract and Table 4: report the compensation **rate** (11/30 vs 30/30), not a binary “effective.” Delete “nine of 31 checks required re-execution” as the current result.

### R1.3 — No experimental benchmark against Arancino

**(a) Concern.** Without a direct comparison, the value of a modular design over an integrated defensive layer remains an assertion.

**(b) Response.** The manuscript includes an architectural comparison (Arancino, COBAI, Peekaboo, EvDetector, out-of-process alternatives). Public Arancino (`necst/arancino`) targets Pin 2.14 + Visual Studio 2010 and, per the DIMVA 2017 paper, 32-bit binaries only. This campaign uses Pin 3.28 and a 100-PE **x64** corpus. A bake-off would confound Pin generation, ISA, OS, and corpus; porting Arancino to Pin 3.28 x64 would not be the published tool. We do **not** claim superiority on coverage, compatibility, or cost. What this revision **does** demonstrate is independent activation, a nine-rung baseline ladder, and combined `-da` on one protocol. Evidence: `experiment/results/oracles/arancino/BLOQUEIO.md`.

**(c) Action.** Keep the related-systems table. Conclusion: no experimental ranking versus Arancino.

### R1.4 — Malicious corpus small and undocumented

**(a) Concern.** Fourteen unclassified samples versus the large-scale studies cited in the introduction.

**(b) Response.** RQ2 now uses **100** Windows PE files: 50 benign (Windows environment) + 50 malicious (MalwareBazaar, 2026-10-14). Each group is 25 short-lived + 25 persistent. `experiment/corpus/corpus.csv` lists SHA-256, source, family/product (`Windows_Console_App`, `Windows_GUI_App`, `Trojan_Bazaar`, `Backdoor_Bazaar`), type, architecture (x64), size, signature, packer/protector, profile, and targeted evasion (`none` / `unverified`). We still do **not** claim that the malware implemented the five hooked checks.

**(c) Action.** Replace every “17 benign / 14 malicious / 31 binaries / 3,100 launches / 155 combinations” sentence. Add a condensed corpus table; point to `corpus.csv` as the auditable supplement.

### R1.5 — Medians without CI; 87.2% working-set drop

**(a) Concern.** Large SkewMask resource deltas may reflect truncated or altered execution, not overhead compensation. Effects this large need uncertainty and a behavioural reading.

**(b) Response.** Group summaries now use the **median of per-binary medians**, IQR, and bootstrap 95% CIs (2,000 resamples, seed 705851366). Rates use Wilson 95% CIs. The old −87.2% WS / −38.5% CPU cells came from a **10 s** window on 31 binaries. Under the prespecified **60 s** window, SkewMask **increases** wall-clock toward the window (benign persistent: TMW0 2.2 s → TMW_DO 60.8 s; paired Δ +55.5 s, CI 30.7–57.0 s). Persistent window-survival rises (benign 8.0% → 52.8%; malicious 54.4% NAT / 32.8% TMW0 → 57.6% TMW_DO). Paired peak-WS Δ (TMW_DO − TMW0): −3.2 MB (CI −58.3 to +0.4, **includes 0**) benign persistent; −22.7 MB (CI −94.9 to −10.7) malicious persistent. Recorded CPU rises under TMW_DO because the process remains scheduled for the full window. We interpret this as a **changed execution state**, not a performance gain.

**(c) Action.** **Delete −87.2 and −38.5.** Replace Table 7 with paired absolute deltas and CIs. State explicitly that a negative WS delta is not an improvement.

### R1.6 — Narrow interception surface versus the title

**(a) Concern.** Alternative APIs (e.g. `NtQuerySystemInformation`, `RDTSC`) bypass the modules; say so in the conclusion, not only in limitations.

**(b) Response.** We agree. “Mitigating evasive techniques” in this paper means suppressing **selected** indicators on **monitored** interfaces. An adaptive program can still detect Pin.

**(c) Action.** Keep the scoped conclusion in §VIII. Do not claim transparency.

---

## Reviewer 2

### R2.1 — Share the matched AntiDebug rerun (`-gdb` vs `-gdb -dd`)

**(a)–(c).** Done. See R1.1. Guest excerpts in `functional_oracles.csv` (`AD_base`, `AD_treat`).

### R2.2 — Redesign SkewMask: predefined repetitions, retain all results, distributions and CIs

**(a)–(c).** Done for the oracle (N=30, all kept; Table in R1.2) and for the corpus (`TMW_DO`, N=10 × 100 binaries, all kept, bootstrap CIs). Do not write “SkewMask is effective” as a binary verdict.

### R2.3 — Native, Pin-only, empty tool, disabled-module, enabled-module baselines

**(a) Concern.** Incremental-only baselines hide the cost of Pin relative to native execution.

**(b) Response.** Nine conditions: NAT (no Pin); EMPTY (Pin + empty pintool); TMW0 (TOMWare, modules off); TMW_DD, TMW_DP, TMW_DE, TMW_DM, TMW_DO; TMW_ALL (`-da`). Bare Pin without a tool is invalid on this Pin 3.28 build (`pin_condition_valid: false`). Median of per-binary median wall-clock, short-lived benign: NAT 0.26 s, EMPTY 1.48 s, TMW0 1.97 s, TMW_DP 5.53 s, TMW_DO 35.0 s, TMW_ALL 36.7 s.

**(c) Action.** New baseline-ladder table in §VI. Future-work item “add native / empty pintool” must be removed.

### R2.4 — Auditable corpus table (SHA-256, source, family, packer, arch, profile, targeted evasion)

**(a)–(c).** `experiment/corpus/corpus.csv` has those columns. Targeted evasion is `unverified` for malware. Add a condensed table in the paper.

### R2.5 — Strengthen comparison with Arancino, COBAI, Peekaboo

**(a)–(c).** Architectural table only (see R1.3). Unique evidenced claim: independent knobs + nine-rung ladder + combined `-da` on one protocol.

### R2.6 — Behavioral-fidelity validation (API traces, coverage, process activity)

**(a) Concern.** Completion or remaining active does not prove equivalent behaviour.

**(b) Response.** We agree. Run records can store process-tree peaks and I/O counters. `module_counters` were **off**; BBL/instruction counts are null. We do **not** claim control-flow, payload, registry, or network equivalence.

**(c) Action.** Compatibility language stays operational. Keep fidelity as a limitation.

### R2.7 — Compatibility is too weakly defined

**(a) Concern.** Process completion or remaining active for 10 s does not prove behavioural equivalence.

**(b) Response.** We agree, and the 9,000-run data make the old **155/155 @ 10 s** claim indefensible. Persistent criterion is now **60 s** `controlled_termination`. Persistent window-survival (n=250, Wilson 95% CI): benign NAT 8.0% [5.2, 12.0], TMW0 9.6%, TMW_DO 52.8% [46.6, 58.9], TMW_ALL 56.4%; malicious NAT 54.4% [48.2, 60.5], EMPTY/TMW0 ≈32–33%, TMW_DO 57.6%, TMW_ALL 64.0%. EMPTY/TMW0 **reduce** malicious persistent survival versus NAT. SkewMask/`-da` raise survival by stretching waits. Short-lived runs are mostly **crash-exit** (not a clean `ExitProcess`); termination class ≥96.8% in every arm. Launch failures: 251/9,000.

**(c) Action.** **Delete 155/155.** Replace Table 5 with outcome classes. Abstract must not say all combinations satisfied the criterion.

### R2 additional — combined mode; proof malware used the five techniques; novelty incremental

**(a) Concern.** No combined-mode evaluation; no proof the malware used the five checks; mechanisms are known, novelty is integration.

**(b) Response.** Combined mode: `TMW_ALL` is in all 9,000-run tables and tracks `TMW_DO` on persistent binaries (SkewMask dominates the joint arm). Proof that corpus malware implemented the five checks: **not demonstrated**. RQ2 remains an operational measurement. Novelty is modular evaluation and the protocol (three properties, nine-rung ladder), which we state as such.

**(c) Action.** Add a TMW_ALL row. One sentence: the 100-sample table is not evidence that each binary exercised the corresponding check. Do not claim new detection primitives.

---

## Reviewer 3 (minor)

### R3.1 — Repeat matched AntiDebug or classify the module as unvalidated

**(a)–(c).** Matched pair done (R1.1). Do not classify AntiDebug as unvalidated.

### R3.2 — Clarify the 29% re-execution rate and selection bias

**(a)–(c).** That 29% (9/31) describes the **old** protocol only. Current oracle: N=30, 0 re-executions, rates 11/30 vs 30/30 (R1.2). Delete 29% from the abstract.

### R3.3 — Add confidence intervals or emphasize that results are descriptive

**(a)–(c).** Wilson CIs on rates; bootstrap CIs on binary-level medians and paired deltas. Still no p-value hunt. Label tables “descriptive with interval estimates.”

### R3.4 — Concise related-systems table

**(a)–(c).** Already in the revision PDF. Keep it.

### R3.5 — Language and formatting pass

**(a)–(c).** Overleaf: normalize decimal points (no locale commas in figures), fix Table 8 wrapping (`TestProcessEnum`), collapse duplicate limitation paragraphs.

---

## Reviewer 4

### R4.1 — Run the matched AntiDebug experiment; do not list it as future work

**(a)–(c).** Done (R1.1). Remove it from the future-work list.

### R4.2 — Report all timing-oracle outcomes; compensation rate; fix the abstract

**(a)–(c).** Done (R1.2). Abstract: “baseline 11/30 below threshold, treatment 30/30, N=30, all attempts retained.” Do not write that SkewMask “kept the oracle below the threshold” as a single verdict.

### R4.3 — Explain or test the 87.2% / 38.5% SkewMask resource results

**(a)–(c).** The 60 s campaign is that test (R1.5). SkewMask fills the observation window and increases recorded CPU because the process remains alive. We adopt Reviewer 4’s reading: the largest effect argues **against** treating “still alive” as compatibility. **Delete −87.2 / −38.5.**

### R4.4 — State the metric-validity rule prospectively

**(a) Concern.** Wall-clock used for some modules and marked N/A for others, with no reconstructable rule.

**(b) Response.** Rule fixed in `experiment.config.json` **before** `corpus_aligned_10k`:

1. Short-lived: wall-clock until natural exit, crash-exit, or 120 s timeout; timeouts retained.
2. Persistent: CPU and peak WS only if `sample_count > 0`; wall-clock is the 60 s window when `controlled_termination` holds, otherwise time-to-exit.
3. ProcessEnum wall-clock is **cost**, not effectiveness (benign short-lived TMW_DP − TMW0 ≈ +3.8 s).
4. Exactly ten repetitions; no rerun because a number “looked wrong.”
5. Launch failures are recorded outcomes (251/9,000), not dropped.

**(c) Action.** Paste this list into §VI Methods. Remove post-hoc N/A cells that cannot be derived from the rule.

### R4 additional — native baseline; figure internals; hook counts; `-da`

**(a)–(c).** Native/EMPTY/TMW0/`-da`: in the 9,000-run ladder. Hook-invocation counters were **off** in those 9,000 JSON. A later 600-run diagnostic (Etapa 5, different DLL) showed ProcessEnum 0/269 and memcmp 0 PIN_ matches; we still do **not** claim the corpus used the five checks. Figure locale (comma vs period) to be normalized in Overleaf.

---

## Reviewer 5

### R5.1 — Clarify or match AntiDebug debugger configurations

**(a)–(c).** Matched (R1.1).

### R5.2 — Moderate behavioural-preservation claims

**(a)–(c).** Abstract and §VI-D: operational criteria ≠ equivalence of system calls, control flow, or external effects. Etapa 6: TMW0 vs TMW_ALL same exit+stdout in 22/30 pairs (external observer only). The 6,517/9,000 label is exit-code unknown, not crash.

### R5.3 — Performance results are descriptive and may reflect execution-state changes

**(a)–(c).** Done (R1.5 / R4.3). SkewMask wall-clock increase is the leading example.

### R5.4 — Strengthen the reference list with recent DBI-evasion studies

**(a)–(c).** Optional. Add only references that the authors have read and that change a claim. Citation of reviewer-suggested papers is not required by IEEE Access.

### R5.5 — Keep conclusions within the oracles and the evaluated corpus

**(a)–(c).** Conclusions: five oracles + 100-binary / nine-condition campaign. No transparency, no Arancino win, no “malware used these five checks.”

---

## Reviewer 6

### R6.1 — AntiDebug configurations differ

**(a)–(c).** Matched (R1.1).

### R6.2 — Timing re-execution / selection bias

**(a)–(c).** Fixed-N=30 oracle (R1.2).

### R6.3 — Weak operational compatibility, especially for malware

**(a)–(c).** 155/155 removed; 60 s survival and crash-exit mix reported (R2.7). No behavioural equivalence.

### R6.4 — No native baseline; only medians

**(a)–(c).** NAT + EMPTY + CIs (R2.3, R3.3).

### R6.5 — Novelty versus existing DBI countermeasure frameworks

**(a)–(c).** Architectural table; no experimental bake-off (R1.3). Novelty stated as modular evaluation and protocol.

---

## Numbers for Overleaf tables (do not invent others)

Canonical file: `experiment/results/oracles/manuscript_values.json` (human summary: `manuscript/notes/VALUES.md`).

**Oracle SkewMask (N=30, all kept).** GO 11/30 below 3000 (median 3,083.210); GO_DO 30/30 (median 2,104.770); TMW0 30/30 (median 2,433.285).

**Oracle AntiDebug (3+3).** `-gdb -q`: 3/3 BeingDebugged=1, NtGlobalFlag=1, IsDebuggerPresent=1. `-gdb -dd -q`: 3/3 all zero. `-da` on all five oracles: exit 0; TestOverhead 2,040.7 < 3,000.

**Corpus completeness.** 9,000 JSON; 6,517 **exited before limit, exit code unknown** (not crash); 1,355 controlled_window; 877 timeout; 251 launch_failed. True exception_crash in the 9,000: 0.

**Persistent window-survival (n=250, Wilson 95%).** Benign NAT 8.0% [5.2, 12.0]; TMW_DO 52.8% [46.6, 58.9]; TMW_ALL 56.4% [50.2, 62.4]. Malicious NAT 54.4% [48.2, 60.5]; EMPTY 32.4% [26.9, 38.4]; TMW_ALL 64.0% [57.9, 69.7].

**Median wall-clock of per-binary medians (ms).** Benign SL: NAT 261, EMPTY 1,485, TMW0 1,974, TMW_DP 5,534, TMW_DO 34,990, TMW_ALL 36,695. Benign P: 254 / 2,180 / 2,190 / 6,094 / 60,770 / 60,746. Malicious SL: 6,165 / 10,332 / 14,004 / 13,747 / 87,009 / 91,086. Malicious P: 60,669 / 16,869 / 15,304 / 18,891 / 60,670 / 60,802.

**Paired TMW_DO − TMW0 (bootstrap 95% CI).** Wall-clock benign P +55,452 ms [30,685, 57,031]; malicious P +37,387 ms [26,146, 42,770] (n_pairs=23). WS benign P −3.2 MB [−58.3, +0.4]; malicious P −22.7 MB [−94.9, −10.7]. TMW_DM − TMW0 malicious SL WS +0.451 MB [0.049, 0.805] (CI excludes 0).

---

## Do not write in Overleaf

- “All combinations were compatible” / 155/155 / 10 s window as the current protocol.  
- −87.2% memory or −38.5% CPU as a gain.  
- “SkewMask always hides Pin” (baseline is 11/30, not 0/30).  
- “The 100 malware samples used the five anti-instrumentation checks.”  
- “TOMWare.M outperforms Arancino.”  
- “Behavioral equivalence / transparency.”  
- IEEE 9,000-run numbers in any JCVHT-only claim, or the reverse.
