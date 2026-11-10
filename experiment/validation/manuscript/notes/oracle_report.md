# Stage 4 — oracle report (VM, 22/10/2026)

Source: `Downloads\etapa4_oracles` copied to `04_oracles/from_vm/`.
Declared timeout: 90 s (Pin probe: 30 s). Collector v2.1: `exit_code` filled (0 on runs that finished).
Timing N=30: **not repeated**. Provenance in CSV `timing_n30_provenance.csv`.

## AntiDebug N=3 (matched)

| Arm | knobs | 3/3 | PEB / IsDebuggerPresent indicators |
|---|---|---|---|
| AD_NAT | native | OK, exit 0 | all 0 |
| AD_TMW0 | `-q` | OK, exit 0 | all 0 (Pin alone does not arm the PEB) |
| AD_GDB | `-gdb -q` | 3/3 alert | BeingDebugged=1, NtGlobalFlag=1, IsDebuggerPresent=1 |
| AD_GDB_DD | `-gdb -dd -q` | 3/3 OK | all 0 |

CheckRemoteDebuggerPresent, ProcessDebugPort and ProcessDebugObjectHandle stayed 0 on every arm (outside `-gdb` and the module).

This closes the manuscript 3+3: baseline `-gdb -q` positive; treatment `-gdb -dd -q` suppresses. NAT and TMW0 without `-gdb` are negative controls.

## `-da` on the 5 oracles

All exit 0, no timeout.

| Oracle | knobs | Result |
|---|---|---|
| TestAntiDebug | `-gdb -da -q` | PEB/IsDebuggerPresent = 0, OK |
| TestProcessEnum | `-da -q` | pin.exe / pinvm / pinipc / TOMWare = 0, OK |
| TestGetEnvironments | `-da -q` | PIN_* = 0, OK |
| TestMemoryScan | `-da -q` | PIN_ / pin.exe / pinvm / pinipc = 0 |
| TestOverhead | `-da -q` | 2040.7 < 3000, OK |

## Pin probe without `-t`

`pin.exe -- TestAntiDebug.exe` finished with **exit 0**, oracle stdout, empty stderr.
On this isolated run Pin without a pintool **worked**. The 9000-campaign `campaign.json` has `pin_condition_valid=false` (old probe, possibly with another Pin running or IPC). Do not claim that Pin without `-t` is always invalid. Claim: the campaign omitted the PIN condition because that day's probe failed; an isolated probe on 22/10 completed.

## Module32 and waits (positive control)

Declared timeout 90 s.

| Run | Result |
|---|---|
| M32 NAT / EMPTY / TMW0 / `-dp` | exit 0, PASS_MASK_OR_CLEAN, pinish=0 |
| WAIT NAT | WAIT_MODEL_OK, alertable 46 ms |
| WAIT EMPTY / TMW0 | WAIT_MODEL_CHECK (alertable ~400 ms): Pin delays waits; the process finishes |
| WAIT `-go` and `-go -do` | timeout 90 s, exit -2 (runner code). Same as the previous run |

Module32 with pinish=0 even without `-dp` does not prove hiding `pinvm.dll`; the right oracle for `pin.exe` remains TestProcessEnum.

## `-mc` smoke — snapshot DLL has counters

`module_events_smoke.json` written (999 bytes). With `-dp`:
`calls_intercepted=140`, `processes_examined=142`, `processes_filtered=3`.
Other modules at 0 (only `-dp` was on). **Stage 5 can use `-mc` without rebuilding.**

## Timing N=30 (reused)

90 runs, hash `76208218...`. Conventional medians: TMW0 2433.285; GO 3083.210 (11/30 below); GO_DO 2104.770 (30/30).
