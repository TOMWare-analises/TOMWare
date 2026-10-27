# IEEE Access Access-2026-38745 — reviewer gap matrix

Campaign just finished: `corpus_aligned_10k`, 9000/9000 JSON, seed `705851366`, Pin 3.28.
Current manuscript PDF still reports the **old** 31-binary / 3,100-launch / 10 s protocol.

| # | Reviewer ask | In current REVISION PDF? | 9000-run campaign? | Still open |
|---|--------------|--------------------------|--------------------|------------|
| R1.1 / R2.1 / R3 / R4.1 / R5.1 / R6 | Matched AntiDebug `-gdb` vs `-gdb -dd` | Yes (3+3 reps, Fig. 2, Table 4) | Oracle, not corpus | Optional: more than 3 reps |
| R1.2 / R2.2 / R3 / R4.2 / R6 | SkewMask fixed-N, keep all timing attempts | **No** — still 9/31 re-exec | Does **not** replace TestOverhead | Must run `Run-MatchedOracles.ps1` N=30 (clone or host after reboot) |
| R1.3 / R2.5 / R3 / R6 | Compare Arancino / COBAI / Peekaboo | Architectural Table (p. ~5–6) | No bake-off | **Etapa 8 bloqueio**; future work = 32-bit + shared-protocol bake-off (`09_values/FUTURE_WORK.md`) |
| R1.4 / R2.4 / R4(e) | Documented / larger corpus | Still 14+17 | **Yes**: 50+50, SHA-256, source, family, profile in `corpus.csv` | Paste table into paper |
| R1.5 / R3 / R6 | CIs / not only medians | Says “descriptive, no CI” | **Yes**: Wilson + bootstrap | Paste Table 7/8 replacements |
| R1.5 / R4.3 / R5.3 | 87.2% WS = state change, not gain | Mentions “may reflect state” but keeps −87.2 | **Yes**: new 60 s window; SkewMask **lengthens** wall clock | **Must delete −87.2 / −38.5 as performance** |
| R1.6 / R5.5 | Title/conclusion vs narrow hooks | Yes in limitations | n/a | Keep; move a sentence into conclusion (already partly there) |
| R2.3 / R4(d) / R6 | NAT, Pin-empty, TMW0, modules, `-da` | Future work item 5 | **Yes**: 9 arms, PIN probe invalid | Paste ladder |
| R2.6 / R4 / R6 | Behavioral fidelity (API/coverage) | Future work item 6 | Schema present; counters off / empty | **Not answered** — moderate claims |
| R2.7 / R4 / R5.2 / R6 | Compatibility too weak | Softened but still 155/155 @ 10 s | 60 s window: **not** 100%; crash-dominated | Replace Table 5; do **not** claim 155/155 |
| R2 extra | Combined mode `-da` | Future work item 4 | **Yes**: TMW_ALL | Paste |
| R2 extra | Proof malware used the 5 checks | Honest negative | Still no hook counts | Keep negative; do not overclaim |
| R4.4 | Prospective metric-validity rule | Mentioned, still post-hoc N/A cells | 60 s / 120 s / 10 fixed reps a priori | Write the rule in Methods |
| R3 language | Typos / spacing | Partial | n/a | Final pass on Word source |
| R5.4 | More references | 23 refs | n/a | Optional 3–5 recent papers |

## What you can submit now vs what still blocks IEEE

**Can be written from this campaign (do it now):** RQ2 redesign — 100 PE, 9 conditions, 9000 launches, CIs, NAT/EMPTY/TMW0/`-da`, honest compatibility, SkewMask resource reinterpretation.

**Cannot pretend the campaign fixed:** RQ1 SkewMask compensation **rate** (still the old 9/31 oracle). Run N=30 on the JCVHT clone (guest Pin). Until then the letter must keep the selection-bias limitation **for the timing oracle only**.

**Cannot do without new work:** Arancino bake-off; API-trace fidelity; “malware used these five checks.”
