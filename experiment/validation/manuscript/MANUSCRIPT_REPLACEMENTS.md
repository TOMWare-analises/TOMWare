# Text to paste into the IEEE Access manuscript (Word/LaTeX source)

The file `Mitigating_...__REVISION_.pdf` is still the **31-binary / 3,100-launch / 10 s** paper. There is no `.docx`/`.tex` in this repo, so these paragraphs must be pasted in the source that generated that PDF, then you export (1) highlighted PDF (2) clean PDF+source.

Highlight every changed sentence in yellow, including the abstract.

---

## ABSTRACT (replace entire abstract)

Dynamic Binary Instrumentation (DBI) enables detailed runtime observation but introduces artifacts that may reveal the analysis environment to evasive programs. This article presents TOMWare.M, a modular defensive Pintool built on Intel Pin for Windows that implements five independently activatable countermeasures against debugging indicators, process and module enumeration, environment variables, memory signatures, and selected timing sources. Five controlled detector applications serve as functional oracles. Under matched simulated-debugging conditions (`-gdb -q` versus `-gdb -dd -q`), AntiDebug suppressed the two monitored PEB fields in all three treatment repetitions and in none of the three baseline repetitions. SanitizePinEnvVars, InstMemcmpMask, and ProcessEnum suppressed their targeted indicators on the intercepted interfaces. The timing oracle uses a **pre-fixed N=30** on TestOverhead.exe (`-go -q` vs `-go -do -q`); every attempt is retained. Baseline: **11/30** below the 3,000-tick threshold (median 3,083.210). Treatment: **30/30** (median 2,104.770). This replaces the old outcome-selected 9/31 re-execution protocol.

Operational effects were re-measured on a **100**-binary Windows PE corpus (50 benign, 50 malicious; 25 short-lived and 25 persistent in each group). Each binary was launched ten times under nine conditions—native (NAT), Pin with an empty pintool (EMPTY), TOMWare with modules off (TMW0), each module alone, and all five (`-da`, TMW_ALL)—yielding **9,000** recorded process launches. Bare Pin without a tool was omitted from the 9,000-run campaign after that day’s probe failed; an isolated later probe completed, so we do not claim the configuration is always impossible. Observation windows were fixed in advance (120 s short-lived timeout; 60 s persistent controlled termination). All attempts were retained. Operational “compatibility” means profile-specific recorded termination or window survival only; it is **not** behavioral equivalence. Most short-lived runs ended with an **uncaptured exit code** (collector artefact), not a demonstrated tool crash. Persistent window-survival under NAT was 8.0% (benign) and 54.4% (malicious). EMPTY/TMW0 reduced malicious persistent survival relative to NAT. SkewMask and TMW_ALL increased survival by stretching wall-clock toward the 60 s window (benign persistent median wall-clock 2.2 s → 60.8 s), which we treat as a change of execution state, not a performance improvement. Incremental Pin cost on short-lived benign binaries was NAT 0.26 s, EMPTY 1.48 s, TMW0 1.97 s (median of per-binary medians). Group summaries include IQR and bootstrap 95% confidence intervals.

---

## I. INTRODUCTION — replace the RQ2 / 31-binary / 3,100 sentences

To answer RQ2, a complementary corpus of **100** Windows PE binaries was used (50 benign applications from a Windows environment and 50 MalwareBazaar samples; 25 short-lived and 25 persistent in each group). Each binary was executed ten times under nine conditions (NAT, EMPTY, TMW0, five single-module arms, TMW_ALL), with condition order randomized inside each (binary × repetition) block and the guest restored from snapshot `tomware_go` after every block. The protocol comprises **9,000** recorded launches. Operational criteria do not establish behavioral equivalence.

**Contributions bullet 3** — replace “31 binaries … 3,100 … 155 combinations” with:

A repeated evaluation of 100 binaries, nine conditions, and ten repetitions (9,000 launches), including native and empty-pintool baselines and combined activation (`-da`), with Wilson intervals on rates and bootstrap intervals on per-binary median contrasts.

---

## VI. PROTOCOL — replace 10 s / no native / 31 binaries

- Restore unit: one snapshot revert per **block** (sample × repetition).  
- Windows: short-lived **120 s** timeout; persistent **60 s** controlled termination.  
- Baselines: NAT, EMPTY, TMW0. Treatments: TMW_DD, TMW_DP, TMW_DE, TMW_DM, TMW_DO, TMW_ALL.  
- Metric-validity rule (a priori): see Response R4.4.  
- Compatibility: short-lived = recorded termination (including timeout or unknown exit); persistent = still active at 60 s (`controlled_termination`). Report outcome classes, not a single PASS. Do not call the 6,517 unknown-exit rows crashes.

---

## TABLE 5 replacement — outcome classes (runs per cell n=250)

Do **not** reprint 155/155.

Persistent window-survival (controlled_window / 250), Wilson 95% CI:

- Benign: NAT 8.0% [5.2, 12.0]; EMPTY 11.2%; TMW0 9.6%; TMW_DO 52.8% [46.6, 58.9]; TMW_ALL 56.4% [50.2, 62.4].  
- Malicious: NAT 54.4% [48.2, 60.5]; EMPTY 32.4%; TMW0 32.8%; TMW_DO 57.6%; TMW_ALL 64.0% [57.9, 69.7].

Short-lived: protocol termination ≥96.8% in every arm; the dominant class is **exit code unknown** (benign ~238–240/250, malicious ~130–169/250). Timeouts: benign 10/250 in every arm; malicious 78–115/250 (higher under TMW_DO/ALL).

Launch failures: 251/9000, concentrated in malicious persistent (~20–23 per condition).

---

## TABLE 7 replacement — delete −87.2 / −38.5

Report **absolute** paired deltas (treatment − TMW0), median across 25 binaries, bootstrap 95% CI. Relative % is optional and never for cells where the baseline is near zero.

| Contrast | Stratum | Δ wall-clock (ms) | Δ peak WS (MB) |
|----------|---------|-------------------|----------------|
| EMPTY − NAT | Benign SL | +1,166 [955, 2,553] | (few NAT resource samples) |
| TMW0 − EMPTY | Benign SL | +151 [26, 270] | +5.7 [4.9, 8.9] |
| TMW_DP − TMW0 | Benign SL | +3,844 [3,427, 4,088] | +0.5 [0.1, 1.0] |
| TMW_DO − TMW0 | Benign SL | +31,669 [13,755, 51,072] | +0.7 [−0.2, 2.2] |
| TMW_DO − TMW0 | Benign P | +55,452 [30,685, 57,031] | −3.2 [−58.3, +0.4] (CI includes 0) |
| TMW_DO − TMW0 | Malicious P | +37,387 [26,146, 42,770] (n_pairs=23) | −22.7 [−94.9, −10.7] |
| TMW_ALL − TMW0 | Benign P | +55,512 [38,005, 56,972] | −5.1 [−74.6, 0.0] |
| TMW_DM − TMW0 | Malicious SL | wall CI includes 0 | **+0.451 [0.049, 0.805]** (do not treat as zero) |
| TMW_DD/DE − TMW0 | most strata | wall-clock CI includes 0 or &lt;1 s | WS CI includes 0 |

CPU under Pin is often 0 on short runs (`sample_count` too small). That filter is **post hoc**; do not publish a CPU % for those cells. Persistent TMW_DO CPU rises because the process **stays alive** — not a SkewMask “saving.”

---

## VII / VIII — replace 155/155 and future-work items 4, 5, 7 that are now done

RQ2 is answered as: enabling a module rarely changes short-lived termination class; Pin (EMPTY) already changes malicious persistent survival versus NAT; SkewMask/`-da` change the **duration and resource path**, not proven payload fidelity.

Future work that **remains**: `NtQueryInformationProcess` / `NtQuerySystemInformation`; `RDTSC`/`RDTSCP`; API-trace / coverage fidelity (Etapa 6 was an external observer only); **32-bit** TOMWare + Pin 3.28 `ia32` (oracles, then optional 32-bit corpus); **Arancino bake-off on a shared 32-bit protocol** (Pin 2.14+VS2010 or a documented port). The current 9,000-run x64 campaign is not that bake-off. Paste `revision_gap_closure/09_values/FUTURE_WORK.md`.

Strike items 4 (combined `-da`), 5 (native/empty baselines), and the “expand corpus + CI” half of item 7 — they are in this revision, together with N=30 timing and AntiDebug 3+3.

---

## What this campaign does **not** let you write

- “SkewMask reliably compensates the timing oracle.”  
- “All 100 binaries remained compatible.”  
- “−87% memory / −38% CPU.”  
- “Malware used the five anti-instrumentation checks.”  
- “TOMWare.M outperforms Arancino.”  
- “Behavioral equivalence / transparency.”
