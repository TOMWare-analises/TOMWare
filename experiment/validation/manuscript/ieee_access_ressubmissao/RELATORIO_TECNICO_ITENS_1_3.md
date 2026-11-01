# Technical close-out — items 1–3 only (Access)

Date: 31/10/2026. Not the article. Not the reviewer letter. Not IEEE.

Items 4–7 of the author request (full temporal coherence, interface matrix, behavioural traces, real evasive case / tool bake-off) were **not executed** and remain declared limitations.

## 1. Pin without Pintool

**New guest N=3 (`pin.exe -- TestAntiDebug.exe`) was not copied to the host.** Classification therefore does **not** call campaign Pin-without-tool incompatible.

| Record | Pin SHA-256 | Result | Use |
|---|---|---|---|
| Guest 22 Oct `pin_probe.csv` | not stored in that CSV | exit 0, empty stderr, oracle OK; CSV still has `pin_condition_valid=false` | historical; flag ≠ raw class |
| Host 30 Oct `pin_bare_probe_host/` | `FBA632E4…741A` = `pin\intel64\bin\pin.exe` | StartServer assert, 718 ms | **not** a substitute for a guest campaign control |
| Documented campaign `pin\pin.exe` | `920A730A…0BB819` | not re-probed in this close-out | required identity for a campaign claim |
| r43c guest Pin path | `FBA632E4…741A` (`intel64\bin`) | used for TMW0/TMW_DO | different file from `pin\pin.exe` |

`campaign.json` `pin_condition_valid=false` stays as the 14 Oct design record that omitted PIN from the 9,000. It was not flipped.

**Reading:** incompatibility of Pin-without-Pintool on the campaign engine is **not confirmed**. Do not write `not_supported_by_engine` from the host probe.

## 2. R4.3c process trees — 27/27 kept

Campaign `access_r43c_process_tree`, `script_rev=r43c.1`, snapshot `tomware_go`, DLL `4BBC6270`, elevated PowerShell (uniform BEN_47 correction), first sample 0–17 ms, interval 50 ms. All attempts preserved.

Pin invoked by the script: `C:\TOMWare\pin\intel64\bin\pin.exe` = `FBA632E4…741A`. Documented campaign launcher `pin\pin.exe` = `920A730A…0BB819` was **not** the file hashed in TMW0/TMW_DO `run_meta.json` (`pin_sha256_matches_campaign=false`).

| Cell | n | Exit / progress | 60 s alive | Named last dump | Named during window |
|---|---|---|---|---|---|
| Native × 9 | 9 | all `−1073741511` in 107–813 ms | 0/9 | 0/9 | 0/9 (dead before CIM name) |
| TMW0 × 9 | 9 | all `−1073741511` in 938–1360 ms | 0/9 | 4/9 | yes where events exist |
| TMW_DO × 9 | 9 | 8× `−1073741511` at 41–59 s; **1× STILL_ALIVE** (BEN_47 r1, 60062 ms) | **1/9** | 3/9 | yes on TMW_DO (pin + PE in `process_events.jsonl`) |

Last-sample named trees (`pin.exe` → sample.exe + `conhost.exe`): TMW0 BEN_46 r1, BEN_47 r1/r2; TMW_DO BEN_28 r2/r3, BEN_47 r1. BEN_28 TMW0 r3 last dump is pin + conhost (sample already gone).

BEN_47 under elevation launched (Native and TMW0/TMW_DO). The r43b Win32 740 did **not** recur. Native BEN_47 is the same `STATUS_ENTRYPOINT_NOT_FOUND` as BEN_28/46.

`process_stayed_alive_60s` is true only for BEN_47 TMW_DO r1. **`behavioral_progress_observed=false` on all 27.** Persistence / wait / a live Pin tree is not recovered application behaviour. `identified=false`. Not the 9,000. Not Arancino.

Raw: `experiment/results/oracles/access_r43c/` (27 folders + `summary.csv`).

## 3. Cited commit public reachability

| Field | Value |
|---|---|
| Cited SHA | `a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3` (replaces `665aebba`; same tree) |
| Present locally | yes |
| Unauthenticated URL | https://github.com/TOMWare-analises/TOMWare/commit/a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3 → **200** |
| Public `main` tip | `86e3994c586a9c5306d204485e839cc91e1def70` (citation stamp) |
| Push | `2ed4daf..86e3994` on `analises/main` |
| Status | **public** |

Cite `a2ee6c9`. Do not cite `665aebba` (404). Raw: `experiment/results/oracles/commit_public_check.json`.

## Items not executed (remain limitations)

Full temporal coherence; full interface matrix / new DLL validation of the 9,000; paired behavioural traces (`-mc` was off); malware check–branch–recovered-behavior case; Arancino / COBAI / Peekaboo bake-off; guest Pin-without-tool N=3 on `920A730A`.
