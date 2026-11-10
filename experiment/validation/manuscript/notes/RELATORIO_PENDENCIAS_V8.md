# Short report - open items v8 (2026-10-27)

Identity. Pin 3.28.98749. Snapshot `tomware_go`.
TOMWare.dll SHA-256 `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`.
Git HEAD `3040df722967fb0e699be6f279837a0611c4ad38` (25/09/2026) does NOT produce this DLL. No tag. We did not rebuild only to create a tag.

Source of the numbers: `C:\Users\marge\Downloads\jcvht_t2_n10_v7b` (campaign `t2_n10_v7b`), identify in `jcvht_identify`, collector in `jcvht_coletor_fumo_v7`. No new N=10/N=30 campaign.

## 1. SkewMask

### TickCount on DO03, DO05, DO07, DO09

Probable cause (consistent with all the data). `Hook_GTC` returns `pGTC() - (DWORD)msOff`, with `msOff` truncated to an integer ms. `CalibratedSleep` increases `g_qpcSkewTicks` when the parallel sleeps finish. Real GetTickCount only advances every ~15.6 ms; if the skew crosses an integer-ms boundary between two readings without real GTC having advanced, the apparent value recedes 1 ms. QPC uses a fine 64-bit subtraction and advances ~0.78 ms between readings, so `qpc_regress=0` in the same interval.

Evidence (`experiment/results/oracles/waits_clock_n10.csv`):
- `clock_during_overlap`: `tick_regress=1` only on DO 03/05/07/09; 0 on the other 36 runs.
- `tick_first < tick_last` on those four (e.g. DO03 779187 -> 779391). Not a 32-bit wrap.
- `clock_burst1000` (no concurrent sleep): `tick_regress=0` on 40/40.
- NAT / EMPTY / TMW0: zero regressions (no GTC hook).

Fix. None in `Hook_GTC`. A monotonic clamp would change the semantics of Table 6. Old DLL left intact.

### Alertable SleepEx, 10/10 timeout 180 s

Location, cause not confirmed. The hang is specific to `SleepEx(500, alertable=true)` under `-do`. The `SleepEx(200, alertable=false)` of the same run RETURNS (`sleepex_nonalert` ~200-270 ms) and the parallel `Thread.Sleep` also return. The test prints `openthread_ok=True` and `queueuserapc_rv=1` and then blocks on `sleeper.Join()`: the thread in alertable SleepEx under `CalibratedSleep` does not wake on the APC.

Evidence. DO 10/10: 12 events, last `sleepex_nonalert`, no `sleepex_alert`. NAT/EMPTY/TMW0 30/30: `rv=192`, `apc_callback=1`, ~45-230 ms. No fault in stderr (not a crash). Collector kills at 180 s -> `exit=-2`. Not an OpenThread failure nor a QueueUserAPC failure.

What was NOT confirmed. I tested the `PatchApi` re-entry hypothesis (last trampoline overwriting `pSleepEx`) and REVERTED: the pointer returned by `RTN_Replace` calls the original, not the hook, so the hypothesis does not hold. `SkewMask.cpp` remained the same as the source of DLL 4BBC6270. The open question is whether the `CalibratedSleep` wrapper breaks alertable APC delivery. Confirming that requires an instrumented build + only the DO/SleepEx test. Without changing SkewMask and without rebuilding until the cause is proven. The N=10 hang remains the recorded result.

## 2. InstMemcmpMask

Cause of exit 2 (evidenced by stderr). `_memicmp_l` has 4 arguments. The hook used `wMemcmpI` with `argc=3`. `memicmp_l_PIN` takes the MASKED branch (does not call the original) and prints `MASKED ret=1`. The following control (`memicmp_l_same`) forwards to the original with the wrong prototype: the 4th argument (locale) is garbage `0xffffffffffffffff` -> `RECEIVED_ACCESS_FAULT`. After 64 faults at the same IP, `Instrumentation.cpp` does `exit(2)`.

Evidence.
- MC3_NAT / MC3_TMW0: exit 0; `memicmp_l_PIN=PASS`; `memicmp_l_same=OK`; `memicmp_l_passthrough=DIFF_OK ret=-1`.
- MC3_DM / MC3_DA: `memcmp` / `_memicmp` / `RtlCompareMemory` MASKED + same/passthrough OK; `memicmp_l_PIN=MASKED`; no `memicmp_l_same`; stderr ACCESS_FAULT at `0xffffffffffffffff`; `timed_out=false`; exit 2.
- ABSENT exports (`RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `bcmp`) remain `NOT_EXERCISED`. `_memicmp_l_export=FOUND`.

Source fix: 4-arg `wMemcmpIL` wrapper + `RTN_ReplaceSignature` with `argc==4`. NOT validated: there is no new build on this machine.

## 3. Practical benefit

Unresolved. 31/31 `identified=false`. Imports/strings are leads (MAL_08 Toolhelp, MAL_12 FindWindow, MAL_14 NtQuerySystemInformation). No executed branch, no NAT / TMW0 / knob triad, no extra artifact with a hash. Remaining active does not count.

## 4. Resources / Table 9

Declared limitation. The 10 s collector (`experiment/results/oracles/collector/`) is synthetic smoke (powershell + PING + file). Table 9 is 17+14 PE / 10 s. There is no same benign and malicious executable with milestones + CPU + WS + peak + tree under NAT / TMW0 / knob. It is not possible to say whether the Table 9 differences are comparable work or altered progress.

## 5. Delivery

- `experiment/validation/manuscript/notes/evidence_matrix.csv` updated.
- `experiment/results/oracles/omitted_files.csv` + `freeze_manifest.py` points at `results/oracles` and no longer deletes the catalog of the 9000 JSON.
- Code: commit `3040df7`, no tag. DLL: SHA-256 above.
- Only source change kept: `InstMemcmpMask.cpp` (`_memicmp_l` as 4 args). `SkewMask.cpp` was NOT changed.
- Open items that are NOT marked resolved: T1 (benefit), Table 9 (resources), confirmed cause of the alertable SleepEx hang, and validation of the `_memicmp_l` fix on a new DLL.
