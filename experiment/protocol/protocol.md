# TOMWare.M experimental protocol

**Normative experiment document**  
**Article:** IEEE Access (Access-2026-38745)  
**Project:** TOMWare.M — rigorous, auditable experimental evaluation

> **Scope:** this document is the protocol of the **100 PE / 9 000-run** campaign.
> The JCVHT 17+14 / 10 s pack and the N=30 oracles are a different campaign (same DLL
> `4BBC6270`). Identity and hashes: repository-root README, **Reproduce**. Do not mix cells.

---

## 1. Scientific objectives and research questions

The experimental design answers the following questions independently:

1. **Q1 — Intel Pin cost:** What is the overhead of running under the Pin engine versus native execution (`PIN - NAT`)?
2. **Q2 — Cost of loading a Pintool:** What is the marginal cost of instantiating a null analysis tool (`EMPTY - PIN` or `EMPTY - NAT`)?
3. **Q3 — Defensive-infrastructure cost:** What is the cost of TOMWare.M loaded with every countermeasure disabled (`TMW0 - EMPTY`)?
4. **Q4 — Incremental cost per countermeasure:** What overhead does each isolated module add (`TMW_DD - TMW0`, `TMW_DP - TMW0`, `TMW_DE - TMW0`, `TMW_DM - TMW0`, `TMW_DO - TMW0`)?
5. **Q5 — Joint-activation cost:** What is the impact of enabling all five modules at once (`TMW_ALL - TMW0`)?
6. **Q6 — Effective module firing:** Is each countermeasure actually invoked during the run, or does it remain passive (internal counters)?
7. **Q7 — Behavioral modification:** Does enabling the countermeasure preserve the application's operational fidelity (processes, APIs, I/O, output)?
8. **Q8 — Survival and completion:** Does the application terminate naturally, or remain observable without operational failure?
9. **Q9 — Suppression on functional oracles:** Are indicators exercised by known stimuli masked under matched conditions (`-gdb` vs `-gdb -dd`; `-go` vs `-go -do`)?
10. **Q10 — Auditability and absence of bias:** Are all raw results kept, with no discard based on a favorable or unfavorable outcome?

---

## 2. Experimental conditions

Conditions are configured via `conditions.csv`:

| Code | Intel Pin | Tool | Parameters | Purpose |
|---|---|---|---|---|
| `NAT` | No | None | *(none)* | Application baseline without instrumentation |
| `PIN` | Yes | None | *(no -t)* | Pure Pin-engine cost (validated by probe) |
| `EMPTY` | Yes | `EmptyPinTool.dll` | *(none)* | Minimum cost of loading a passive Pintool |
| `TMW0` | Yes | `TOMWare.dll` | `-q` | TOMWare.M infrastructure with defenses off |
| `TMW_DD` | Yes | `TOMWare.dll` | `-dd -q` | Isolated AntiDebug effect |
| `TMW_DP` | Yes | `TOMWare.dll` | `-dp -q` | Isolated ProcessEnum effect |
| `TMW_DE` | Yes | `TOMWare.dll` | `-de -q` | Isolated SanitizePinEnvVars effect |
| `TMW_DM` | Yes | `TOMWare.dll` | `-dm -q` | Isolated InstMemcmpMask effect |
| `TMW_DO` | Yes | `TOMWare.dll` | `-do -q` | Isolated SkewMask effect |
| `TMW_ALL` | Yes | `TOMWare.dll` | `-da -q` | Combined effect of all five modules |

*Note on the PIN condition:* Intel Pin by default requires a tool (`-t`) to load the executable in JIT mode. The experimental probe tests `pin.exe -- app.exe`. If `pin.exe` refuses to run without `-t`, condition `PIN` is recorded in the manifest as technically unsupported, and `EMPTY` becomes the minimum Pin baseline (9 operational conditions).

---

## 3. Sampling design and block randomization

To avoid confounding experimental condition with run order or time of day:

1. **Sample blocks:** Each block is a pair `(sample_id, repetition)`.
2. **Randomized order:** Inside each block, every valid condition runs exactly once, in a pseudorandom order generated from a recorded seed.
3. **Recorded seed:** The seed is stored in `randomization_seeds.csv` and in each run header, so the sequence is deterministically reproducible.
4. **Strict execution:** The planned order is never changed because of an unexpected result. Failures and timeouts are recorded exactly where they occurred.

---

## 4. Isolation unit and environment restore

To avoid cumulative contamination across runs:

- **Restore unit:** Clean snapshot reverted every **block** (sample + repetition).
- **Technical rationale:** Reverting per block (10 conditions) balances containment rigor and wall-clock feasibility, so each sample starts its round from the same OS state.
- **Network:** Interface disabled or restricted to host-only with no external route.
- **Residue check:** The runner scans for leftover processes before each block and after each run (`taskkill /F /T` for remaining instances).
- **Identity:** `snapshot_id` and restore-completion status are recorded in each individual JSON.

---

## 5. Temporal profiles and observation windows

1. **Short-lived applications (`short_lived`):**
   - Wait for natural completion.
   - Timeout fixed at 120 seconds.
   - Record whether they completed naturally, timed out, or hit an exception/crash.
   - Preserve SHA-256 hashes of stdout and stderr.

2. **Persistent applications (`persistent`):**
   - Standardized observation window of 60 seconds.
   - Continuous resource time series (200 ms interval).
   - At the end of the window, controlled termination by the runner (`controlled_termination`).
   - Remaining alive is **not** treated as functional equivalence.

---

## 6. Functional oracles

Independent campaign on `Resultados/Apps-Teste/`:

- **AntiDebug:** Matched comparison under the same stimulus:
  - Baseline: `pin.exe -t TOMWare.dll -gdb -q -- TestAntiDebug.exe`
  - Treatment: `pin.exe -t TOMWare.dll -gdb -dd -q -- TestAntiDebug.exe`
  - Negative control: Pin-only without `-gdb`.
- **SkewMask:** Matched comparison with a frozen $N=30$ protocol and no sample discard:
  - Baseline: `pin.exe -t TOMWare.dll -go -q -- TestOverhead.exe`
  - Treatment: `pin.exe -t TOMWare.dll -go -do -q -- TestOverhead.exe`
  - Report the compensation rate (% of ticks below the 3000 threshold), median, IQR, and 95% CI.
- **ProcessEnum:** `TestProcessEnum.exe` with Tool Help (`pin.exe` filtered).
- **SanitizePinEnvVars:** `TestGetEnvironments.exe` (`PIN_*` variables renamed to `ZZZ_*`).
- **InstMemcmpMask:** `TestMemoryScan.exe` (`memcmp` interception).

---

## 7. Statistical analysis at the binary level

Repetitions are nested in the executable. The mandatory statistical procedure is:

1. **Run level:** Raw metrics (monotonic time, user/kernel CPU, peak WS, peak private).
2. **Binary level:** Median of valid repetitions for each pair `(binary, condition)`.
3. **Paired contrasts:** Differences computed inside the same binary ($TMW_X - TMW0$, etc.).
4. **Stratum aggregation:** Median, IQR, and 95% bootstrap confidence interval at the binary level.
5. **Proportions:** Completion and suppression rates with a 95% Wilson confidence interval.
6. **No reliance on unstable percentages:** When the baseline is near zero, the absolute difference is reported as mandatory.
