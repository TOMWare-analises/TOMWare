# Permitted reading — R4.3 process tree

Three campaign ids. Table 25 of the article/letter uses **only** `access_r43b_process_tree`.
`access_r43c_process_tree` is extra evidence (N=3, elevation). Do **not** paste r43c into Table 25.
`identified=false` on all. Persistence ≠ progress. Does not rewrite the 9,000. Is not Arancino.

DLL: `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`.
Window 60 s. N=1. Knobs: Native = (empty); TMW0 = `-q`; TMW_DO = `-do -q`.
Snapshot `tomware_go`.

---

## A. Preserved: `access_r43_skewmask_diag` (29/10/2026)

Folder in the pack: `r43_skewmask_diag/`.

`process_tree.txt` on all nine: `tree_error` — `$pid` is a read-only automatic variable in PowerShell. Tree evidence in that campaign is only `n_tree` in `resources.csv`. Do not use these numbers as a named parent/child tree.

| sample | mode | progress | exit_code | elapsed_ms | peak_ws |
|---|---|---|---|---|---|
| BEN_28 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 1609 | 0 |
| BEN_28 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1687 | 70164480 |
| BEN_28 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61016 | 68624384 |
| BEN_46 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 781 | 0 |
| BEN_46 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1938 | 67272704 |
| BEN_46 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61234 | 68521984 |
| BEN_47 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 750 | 0 |
| BEN_47 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1703 | 71753728 |
| BEN_47 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61062 | 69128192 |

---

## B. Table 25: `access_r43b_process_tree` (30/10/2026, `script_rev=r43b.2`)

Folder in the pack: `r43b_process_tree/`. Script: `Run-AccessR43b.ps1` (`$procId`; CSV `name,pid,parent_pid,depth`).

SHA:
- BEN_28 `0111d485351ef0deffd9403a0f8e123759a04a928fbd055b901de18164c4fa39`
- BEN_46 `0ab9f2923dac072716a8380ec909ea9f74b9f1755f149c2a41f61b49d93633a2`
- BEN_47 `0abd30c5a4a6f17c9f1f718da42435ed05927a3c0ee5430a8ff337027f875dfd`

| sample | mode | progress | exit_code | elapsed_ms | peak_ws | named tree |
|---|---|---|---|---|---|---|
| BEN_28 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 3375 | 0 | none (`?` parent=-1) |
| BEN_28 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1625 | 65306624 | live `n_tree=3` then post-mortem `?` |
| BEN_28 | TMW_DO | EXITED_BEFORE_WINDOW | -1073741511 | 49344 | 79572992 | live `n_tree=3` ~49 s then dead. Not window fill |
| BEN_46 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 1155 | 0 | none |
| BEN_46 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1625 | 73228288 | `pin.exe` → sample.exe + `conhost.exe` |
| BEN_46 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61063 | 70381568 | same named tree |
| BEN_47 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 437 | 0 | none |
| BEN_47 | TMW0 | EXITED_BEFORE_WINDOW | -1 | 719 | 10702848 | Pin fatal Win32 740 (elevation) |
| BEN_47 | TMW_DO | EXITED_BEFORE_WINDOW | -1 | 453 | 10829824 | Pin fatal Win32 740 (elevation) |

Named tree (BEN_46 TMW0 and TMW_DO), `process_tree.csv`:

```
name,pid,parent_pid,depth
pin.exe,<pid>,<parent>,0
0ab9f2923dac072716a8380ec909ea9f74b9f1755f149c2a41f61b49d93633a2.exe,<pid>,<pin>,1
conhost.exe,<pid>,<pin>,1
```

BEN_47 TMW0/TMW_DO `stdout.txt` / `drop/pin.log`: `System error 740 : A operação solicitada requer elevação.` (verbatim Windows message: “The requested operation requires elevation.”). This is **not** `STATUS_ENTRYPOINT_NOT_FOUND` and is **not** a SkewMask hold.

N=1. Native/TMW0 times differ from the r43 campaign; do not mix the two tables.

---

## C. Extra only: `access_r43c_process_tree` (31/10/2026, `script_rev=r43c.1`)

Folder in the pack: `r43c_process_tree/`. **Not Table 25.** N=3, elevated session, sample 50 ms, first sample immediate. 27/27 retained.

Pin hashed on the TMW0/TMW_DO cells: `FBA632E4…741A` = `pin\intel64\bin\pin.exe`. This is **not** the documented launcher `pin\pin.exe` `920A730A…0BB819` (`pin_sha256_matches_campaign=false`).

| Cell | n | Exit | 60 s alive | Named last dump |
|---|---|---|---|---|
| Native × 9 | 9 | all `−1073741511` in 107–813 ms | 0/9 | 0/9 |
| TMW0 × 9 | 9 | all `−1073741511` in 938–1360 ms | 0/9 | 4/9 |
| TMW_DO × 9 | 9 | 8× `−1073741511` at 41–59 s; 1× STILL_ALIVE BEN_47 r1 60062 ms | **1/9** | 3/9 |

Named last (`pin.exe` → sample + `conhost.exe`): TMW0 BEN_46 r1, BEN_47 r1/r2; TMW_DO BEN_28 r2/r3, BEN_47 r1. `process_events.jsonl` can show pin+PE during the window even when the last dump is `?`.

BEN_47 under elevation launched. The r43b Win32 740 did **not** recur. Native BEN_47 = the same `STATUS_ENTRYPOINT_NOT_FOUND` as BEN_28/46.

`behavioral_progress_observed=false` on the 27. `identified=false`. 1/9 alive ≠ progress. Guest Pin-without-tool N=3 was not copied; incompatibility is **not** confirmed.

---

## Permitted interpretation

1. On these three SHA, on snap `tomware_go`, native **does not enter** (`STATUS_ENTRYPOINT_NOT_FOUND`). This is not “a persistent binary at work”.
2. In Table 25 (r43b) the only **named** parent/child tree in the final dump is BEN_46: Pin launcher, target PE, `conhost.exe`.
3. TMW_DO BEN_46 r43b fills the 60 s window with that tree. That is wait/state, not a recovered GUI.
4. TMW_DO BEN_28 r43b had a live tree ~49 s and then the same entry-point exit. Do not count as `STILL_ALIVE`.
5. BEN_47 r43b under Pin failed to launch (UAC/elevation). In r43c, with elevation, 740 did not recur; that does **not** promote r43c to Table 25.
6. r43c: 1/9 TMW_DO alive (BEN_47 r1) and intermittent named trees. Persistence / live Pin ≠ progress.
7. Without API traces one cannot distinguish “the target ran” from “Pin stayed alive”. Classify **inconclusive** as to progress.
8. Two `pin.exe`: `920A730A` (documented campaign) ≠ `FBA632E4` (r43c / host intel64). Do not merge the identities.

## What this is not

Not an Arancino bake-off. Not proof of an evasive check. Does not rewrite Table 19. Not API equivalence. Not the JCVHT `TestRecoverWork` demonstrator. Not 155/155 and not −87.2%.
