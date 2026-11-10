# Overleaf adjustments JCVHT (v3; 26/10/2026)

A single timing rule: N=30 in the body; old table in the appendix.
Do not delete numbers. Replace the 49% phrases and "-da was not evaluated".
TMW0 = Pin + TOMWare, knobs off -- not "ordinary Pin".
Optional figures, attached separately. Extra Plan B until 02/11.

## Table 6 (matched timing) -- body

| Arm | Knobs | N | Median ticks | Min-max | Below 3000 |
|---|---|---|---|---|---|
| TMW0 | `-q` | 30 | 2433.285 | 2168-2750 | 30/30 |
| GO | `-go -q` | 30 | 3083.210 | 2722-3845 | 11/30 (36.7%) |
| GO_DO | `-go -do -q` | 30 | 2104.770 | 2073-2146 | 30/30 |

Oracle: anomaly if score **>** 3000 (OK if **<=**). No value = 3000.
Do not use `matched_timing_summary.csv`.
Old cell `-go` vs `-do` (e.g. 4080 vs 2081 / ~49%): **appendix only**, labeled confounded.

## Abstract

Five modules **selectable and oracled separately**.
TMW0 = Pin with TOMWare loaded and knobs off (`-q`), not ordinary Pin.
Quantitative SkewMask claim: **11/30 vs 30/30**, not the old cell and not the 10 s WS %.

## Phrases to REPLACE (a caption note is not enough)

1. Any functional conclusion from the ~49% / 4080 vs 2081 difference:
   the old cell is confounded; the result of this revision is the N=30 table.
2. Any phrase "-da was not evaluated":
   `-da` was smoke-tested on the five detectors (tab:da_smoke); it is not a 3,100 campaign.

## Table 9

Label the window **10 s / 31 PE**. Use the % already in the article (review: WS 87% and 74%; CPU 38% and 29%). **Not** as a gain. Cite +55,452 ms / +37,387 ms only as the **60 s / 50+50** campaign, another one.

## Waits (5.5)

We do not guarantee a globally coherent clock under Pin. N=5 QPC (24/10):
native `par_wall` 213.678 < seq 406.218; EMPTY/TMW0/`-do` have `par_wall` 571.867 / 553.862 / 517.802 (Join longer than seq).
The two `Sleep` **still overlap** under Pin (median intersection ~207 / 212 / 196 ms; fraction 0.70-0.99). Do not write that Pin serializes the waits.
What fails is the `par_wall < seq` model, from creation/Join/JIT overhead, not the geometry of the two Sleeps.
Alertable ~46 ms **only** native (`WaitOne`, not `SleepEx`). TickCount (one pair) did not go backwards; that does not prove general monotonicity.
SkewMask = process offset (`AccumulateSkewTicks`). Do not write that it restores concurrent geometry nor that `double_count_risk` proves double counting of the offset.
EMPTY = Pin + `EmptyPinTool.dll`, not Pin without a tool.

## Module32 (Table 8 / functional)

24/10 fixture: dummy `pinvm.dll` (copy of `version.dll`) visible NAT/TMW0, hidden `-dp`/`-da`; `kernel32` kept. Do not write that the dummy is a real Pin module. ProcessEnum: pin.exe 0 / 3 / 0 / 0.

## memcmp family

Oracled: `memcmp`, `_memicmp`, `RtlCompareMemory` (PASS vs MASKED). `wmemcmp` and `RtlEqualMemory` with no export on the guest. Do not cite `SAME_BAD` (n=7 equal by construction).

## Major 3

Practical benefit **not demonstrated**. MAL_03/07/10 and BEN_06 **are not** a case study. Table of the 14 = oracle/compatibility.

## Table 8

Wrap the TestProcessEnum column. One limitations subsection.

## Methods

Pin **3.28.98749**. DLL SHA-256 prefix **4BBC6270**. Snapshot `tomware_go`. Without `3040df7`.
TMW0 = Pin + TOMWare, knobs off.
