# Point by point -- what the article must say (Plan A v3)

Each block: (a) what the reviewer asked, (b) what we measured, (c) what to paste into Overleaf, (d) what not to write.
Software of the whole campaign: Pin **3.28.98749**, DLL SHA-256 starting with **4BBC6270**, snapshot `tomware_go`. Without commit `3040df7`.
TMW0 = Pin + TOMWare.dll, five knobs off (`-q`). It is not ordinary Pin / bare Pin. EMPTY = Pin + EmptyPinTool.dll.

Single timing rule: N=30 in the **body**; old `-go` vs `-do` table in the **appendix**, labeled confounded. Do not delete the old numbers.

---

## Editor (Eric Filiol) -- E.1

**(a)** Exact results, no overclaim, explicit limitations; point-by-point letter.

**(b)** The EN letter in this zip is that response. Four PE tried as a case study produced no milestone.

**(c)** One limitations subsection (do not repeat the same paragraph in three places). Keep the M2 and M3 concessions.

**(d)** Do not claim that "staying alive under Pin" is preserved malware behavior. The 14x5 PASS table is an **oracle**, not proof that those PE used the five checks.

---

## Reviewer -- Major 1.1 (matched timing)

**(a)** Table 6 compared `-go` with `-do`. Request: same load, `-go` vs `-go -do`, plus Pin without `-go`, all attempts.

**(b)** TestOverhead.exe, N=30, nothing discarded. TMW0 is Pin + TOMWare with knobs off, not ordinary Pin.

| Arm | Knobs | N | Median ticks | Min-max | Below 3000 |
|---|---|---|---|---|---|
| TMW0 | `-q` | 30 | **2433.285** | 2168-2750 | 30/30 (100%) |
| GO | `-go -q` | 30 | **3083.210** | 2722-3845 | 11/30 (36.7%; Wilson 95% [21.9%, 54.5%]) |
| GO_DO | `-go -do -q` | 30 | **2104.770** | 2073-2146 | 30/30 (Wilson [88.6%, 100%]) |

Oracle: anomaly if score **>** 3000 (OK if **<=**). No value landed on 3000.

**(c)** Put this table in the **body** as the main result (tab:timing_matched_n30). Move the old Table 6 to the **appendix** (app:timing_confounded), with the original numbers and the note "confounded". Abstract: rate **11/30 vs 30/30**, not binary "SkewMask effective". Replace any phrase of ~49% / 4080 vs 2081.

**(d)** Do not use `matched_timing_summary.csv` (lower element of the pair: 2417.74 / 3079.08). Do not delete the old table -- move it. Do not go back to 9/31. Do not call TMW0 ordinary Pin.

---

## Reviewer -- Major 1.2 (waits / clock / early return)

**(a)** Test seq, concurrent, repeated readings and a wait that returns early. If there is no coherent timeline, declare a limitation.

**(b)** TestConcurrentWaitsLogged, N=5, without `-go`, 20/20 exit 0. Medians (ms):

| Arm | seq 2x200 | Join wall | Tick+50 | WaitOne(500) |
|---|---|---|---|---|
| NAT | 406.218 | **213.678** | 62 | **45.867** |
| EMPTY (Pin + EmptyPinTool) | 433.421 | 571.867 | 62 | 445.610 |
| TMW0 (`-q`) | 441.209 | 553.862 | 78 | 441.411 |
| `-do -q` | 414.809 | 517.802 | 56 | 383.428 |

The two Sleep **still overlap** under Pin (median intersection ~207 / 212 / 196 ms; fraction 0.70-0.99). TickCount (one pair) did not go backwards. WaitOne ~46 ms only on native.

**(c)** Paste: *We do not guarantee a globally coherent clock under Pin. The Join wall becomes larger than sequential under Pin; that does not mean the Sleeps were serialized. SkewMask accumulates a process offset and does not restore the Join-wall < seq model.*

**(d)** Do not write: "Pin inverts/serializes the overlap"; "SkewMask preserves concurrent geometry"; "EMPTY = Pin without a tool"; "WaitOne proves SleepEx".

---

## Reviewer -- Major 1.3 (timeouts without stdout)

**(a)** Diagnose instrumented runs with no output.

**(b)** The same wait oracle with `-go` / `-go -do` times out -2 in 90 s. Cause: `SimulateOverhead` inserts 10,000 `__nop` **before each instruction**. TestOverhead completes under `-go` and `-go -do` (N=30 table).

**(c)** One sentence: -2 is a load-generator timeout, not a SkewMask crash.

**(d)** Do not treat -2 as a tool failure nor as a clock going backwards.

---

## Reviewer -- Major 2 (CPU / memory / milestones / tree)

**(a)** Explain the large WS/CPU drops; comparable milestones; window; parent/child tree.

**(b)** Two windows, different protocols:
- **This article, Table 9:** 10 s, 31 PE. The published % (review: WS 87% and 74%; CPU 38% and 29%) are from this protocol only.
- **Later 50+50 campaign (60 s):** SkewMask **stretches** the wall. Benign persistent TMW_DO-TMW0: **+55,452 ms** [30,685, 57,031]. Malicious persistent: **+37,387 ms** [26,146, 42,770] (n_pairs=23). Benign P WS -3.2 MB (CI includes 0). No named tree; `child_count` under Pin is not a useful child process.

**(c)** Label Table 9 with **10 s / 31 PE**. Say that "still running" is not "the same work". Cite +55 s / +37 s only as the **60 s / 50+50** campaign.

**(d)** Do not republish -87% / -38% as a gain. Do not import the +55 s as if they were Table 9. Do not invent a process tree.

**Honest status:** partial (no comparable milestones nor WS/CPU series per PID in this pack).

---

## Reviewer -- Major 3 (practical benefit) -- concession

**(a)** Show that the 14 malware used the checks; case studies with identified check, branch and extra behavior.

**(b)** The PASS table is an oracle. Four candidates (MAL_03, MAL_07, MAL_10, BEN_06), NAT / TMW0 / `-do`, 60 s: `new_files=0`, empty stdout, check in the PE not located.

| Sample | NAT | TMW0 (`-q`) | `-do -q` |
|---|---|---|---|
| MAL_03 | timeout 60 s | ACCESS_VIOLATION 0xC0000005 (~35 s) | timeout ~64 s |
| MAL_07 | exit 0 ~1.4 s | ACCESS_VIOLATION 0xC0000005 (~4 s) | timeout ~62 s |
| MAL_10 | timeout 60 s | timeout ~64 s | timeout ~64 s |
| BEN_06 | exit 3 ~1.0 s | exit 3 ~3.8 s | timeout ~62 s |

**(c)** Mandatory sentence: *Practical recovery of suppressed malware behavior **is not demonstrated**. The table of the 14 is oracle/compatibility only. MAL_03/07/10 and BEN_06 are not a case study.*

**(d)** Do not write that the malware used the five checks. Do not treat "still alive at 60 s" as unpack/drop/C2.

**Honest status:** not addressed (request answered by concession).

---

## Reviewer -- Major 4.1 (Module32)

**(a)** Positive control: pass-through vs mask, termination, unrelated entries.

**(b)** TestModule32 (Stage 4): termination + `kernel32=1`, but `pinish=0` already without `-dp` (does not prove a filter). 24/10 fixture: copy of `version.dll` as `%TEMP%\pinvm.dll` (**dummy, not Pin**).

- NAT: `fixture_pinvm=1`, count=32
- TMW0: `fixture_pinvm=1`, count=31
- `-dp` / `-da`: `fixture_pinvm=0`, count=30
- `kernel32=1` and `terminated=True` on all four

ProcessEnum (`processenum_base.csv`): pin.exe NAT=0 / TMW0=3 / `-dp`=0 / `-da`=0.

**(c)** Cite the fixture for hide/show of the dummy. Cite TestProcessEnum for `pin.exe`.

**(d)** Do not write that the dummy is a real Pin module. Do not claim a `pinvm` filter from the old TestModule32 alone.

---

## Reviewer -- Major 4.2 (memcmp family)

**(a)** Pass-through vs mask on the advertised interfaces.

**(b)** Exercised: `memcmp`, `_memicmp`, `RtlCompareMemory` -- NAT/TMW0 = PASS; `-dm`/`-da` = MASKED.
Not exercised: `RtlEqualMemory`, `wmemcmp` (`EntryPointNotFound`).
`memcmp_passthrough=SAME_BAD` with n=7 of AAAAAAAA vs AAAAAAAB and equality by construction -- not a defect.

**(c)** TestMemoryScan = C++ `memcmp` control. Cite the three C# APIs. Keep NOT_EXERCISED on the others.

**(d)** Do not claim the 12 routines. Do not cite SAME_BAD as a tool failure.

**Honest status (M4 as a set):** partial.

---

## Reviewer -- Major 4.3 (`-da`)

**(a)** Small joint test on the oracles.

**(b)** 5/5 exit 0: AntiDebug zeros; ProcessEnum pin.exe=0; environment PIN_*=0; MemoryScan PIN_/pin.exe/pinvm/pinipc=0; TestOverhead 2040.7 < 3000.

**(c)** REPLACE the phrase "-da was not evaluated". One sentence + table tab:da_smoke. `-da` does not enable `-go`.

**(d)** Do not leave the old phrase in the article with only a caption note.

---

## Reviewer -- Minor 1 (reproduction)

**(a)** Pin commit/release; state the window and corpus selection.

**(b)** Pin 3.28.98749; DLL prefix **4BBC6270**; snapshot `tomware_go`. Git hash `3040df7` is outdated.

**(c)** Methods: Pin version + DLL prefix + window **10 s** in this article. 50+50 campaign = 60/120 s, another one. Submitted corpus: 17+14 PE; `exclusions.csv`. No invented VirusTotal families.

**(d)** Do not identify the campaign by `3040df7`.

---

## Reviewer -- Minor 2 (text / Table 8)

**(a)** Shorten repeated limitations; wrap the TestProcessEnum column.

**(b)** Editorial. No new experiment.

**(c)** One limitations subsection. Adjust the Table 8 wrap.

---

## Reviewer -- Minor 3 (abstract)

**(a)** Revise the "five countermeasures" sentence after the corrected timing.

**(c)** *Five modules selectable and oracled separately. TMW0 = Pin + TOMWare, knobs off. The quantitative SkewMask claim is 11/30 vs 30/30, not the old `-go` vs `-do` cell nor the 10 s WS percentages.*

---

## After editing

Return the article PDF. We will check against this list. Journal submission = already edited article + EN letter (`01_...pdf`).
