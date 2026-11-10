# Item-by-item response — Access after the 9 access_m3_cases cells

Do not send to IEEE. This is not the double-blind supplement. No malware. Not the 9,000.
Citation: git a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3.
DLL 4BBC6270. Launcher `pin\pin.exe` 920A730A (`pin_sha256_matches_campaign=true` on all 9).
Campaign `access_m3_cases`, script `m3c.4`, N=1, 60 s, `-mc` on, network off, snapshot `tomware_go`.
`identified=false` and `chain_complete=false` on all. No samples are added.

A priori SHA (IAT is a hint, not a case):
- MAL_07 `153e1147…19800d`
- MAL_13 `2a2b6b75…ebb9e24`
- MAL_08 `1693df9d…417b6d38`

## 1. Relate malware, check, and countermeasure

**Executed. Negative / inconclusive result. Not resolved.**

The requested sequence (sample called the API → hook incremented → result changed → module identified) **does not appear in any cell**.

| Sample | TMW0 | TMW_DP (`-dp`) | TMW_DO (`-do`) |
|---|---|---|---|
| MAL_07 | JSON ok; all counters 0; crash `0xC0000005` + WerFault + SINGLE_STEP_TRAP | **INVALID:** Pin did not map the DLL (Win32 216) | alive 60 s; JSON absent |
| MAL_13 | alive 60 s; JSON absent | alive 61 s; JSON absent; no 216 | alive 60 s; JSON absent |
| MAL_08 | alive 62 s; JSON absent | alive 61 s; JSON absent; no 216 | alive 60 s; JSON absent |

Only two cells wrote `module_events.json` (MAL_07 TMW0 and MAL_07 TMW_DP). TMW0 does not install `-dp`/`-do` hooks. MAL_07 TMW_DP is invalid. In the remaining cells the JSON was not dumped (Pin dead at the end of the window). A Toolhelp/SleepEx IAT is **not** an executed branch. This does **not** authorize writing that the 100 PE use the five checks.

## 2. Additional behavior on selected cases

**Executed. Negative result. Not resolved.**

No cell has extra versus TMW0 (hashed file, Run/RunOnce, TCP, child that is not pin/conhost).

The only absolute “extra child” was `WerFault.exe` on MAL_07 TMW0 — a crash reporter, not payload. Typical tree: `pin.exe` → `pin.exe` → sample + `conhost`. Alive at 60 s is not unpacking, configuration, a file, registry, network, or a new phase.

Complete chain: **0/6** TMW0×knob pairs.

## 3. Explain SkewMask behaviorally

**Executed on the three SHA. No interception proof. Not resolved as a gain.**

| Sample | TMW0 ms | TMW_DO ms | extra vs TMW0 | Reading |
|---|---|---|---|---|
| MAL_07 | 10,969 (crash) | 60,204 (alive) | no | longer duration = wait/state; TMW_DO JSON absent; no artifact |
| MAL_13 | 60,329 | 60,109 | no | same window; SkewMask did not lengthen or produce extra |
| MAL_08 | 62,031 | 60,422 | no | same window; same |

No `sleep_calls` / `time_queries` / `corrections` demonstrated on TMW_DO (JSON absent). r43d (BEN_28/46/47) remains separate and is benign.

## 4. Temporal coherence of SkewMask

**Not run. Limitation.** Timeouts under Pin on concurrent/overlapping/alertable waits remain inconclusive. `SkewMask.cpp` was not altered. JCVHT cells are not copied.

## 5. Pin without a Pintool on the corpus

**Limitation.** Only the technical N=3 control on `TestAntiDebug` (920A730A, 3/3 exit 0, 1900–2963 ms). Not an arm of the 100 PE. `campaign.json` `pin_condition_valid=false` was not inverted.

## 6. Incomplete metadata

**Limitation.** `Trojan_Bazaar` / `Backdoor_Bazaar`; packer `unknown`; `targeted_evasion=unverified` on the 50 MAL. These 9 cells did not identify a technique at runtime.

## 7. External experimental comparison

**Limitation / future work.** No Arancino, COBAI, or Peekaboo bake-off. Arancino: Pin 2.14, 32-bit; Access corpus 100% x64.

## 8. Prospective criteria

The three SHA and the three arms were fixed **before** this run. The 9,000 campaign remains post hoc. It is not replaced by a new corpus collection.

## What the letter may say

Three a priori malicious PE were run, TMW0 / TMW_DP / TMW_DO, campaign launcher, `-mc` on. The check → module → extra-behavior chain was not observed. Persistence at 60 s and the pin+conhost tree are not progress. IAT is not execution. Items 4–8 remain limitations.

## What the letter must not say

- the 100 use the five checks
- IAT of MAL_07/13/08 = executed check
- longer TMW_DO on MAL_07 = a SkewMask gain
- alive 60 s / pin+conhost = recovered behavior
- `identified=true`
- Arancino bake-off
- the 9,000 revalidated by these 9 cells
