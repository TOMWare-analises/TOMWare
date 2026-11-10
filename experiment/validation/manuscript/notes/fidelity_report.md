# Stage 6 — fidelity report (Q7)

Source: `Downloads\etapa6_fidelity` -> `06_fidelity/from_vm/`.
Snapshot DLL: hash starts with `4BBC6270` (9000 campaign). No FidelityProbe.
Observer: `external_ps` (exit, duration, SHA-256 stdout/stderr, child processes, new files in TEMP/Public/Desktop/Downloads).
10 PE x NAT / EMPTY / TMW0 / TMW_ALL x 3 = **120/120**. Timeout 45 s.

## Coverage

All arms: 30 runs. Samples: BEN_05/06/10/12/14, MAL_01/02/06/07/11.
Timeouts (`-2`): 5 (BEN_06 TMW_ALL 3/3; BEN_12 TMW_ALL 2/3).
AV `0xC0000005`: 4 (MAL_07 EMPTY 2, TMW_ALL 2).
New files: 11/120. Observed children: 100/120 (many are the target itself).

## TMW0 vs TMW_ALL (effect of the 5 modules)

30 pairs (sample, attempt). Exit+stdout equal: **22**. Different: **8**.

| Sample | TMW0 | TMW_ALL | Reading |
|---|---|---|---|
| BEN_05 | exit 1, stdout 0 | exit 1, stdout 0 (~40 s) | Same outcome; slower |
| BEN_10 | exit 0, 6941 B | exit 0, 6941 B (same SHA) | identical stdout |
| BEN_14 | exit 11, 28 B | exit 11, 28 B (same SHA) | identical stdout |
| BEN_12 | exit 0, 754 B | 754 B; 2/3 timeout | Same text; process does not exit in time |
| BEN_06 | exit 3 | timeout 3/3 | `-da` changes the outcome |
| MAL_01/02/11 | exit 2, stdout 0/255 | same as TMW0 | Pin already changed vs NAT; `-da` does not change further |
| MAL_06 | 2x exit 2, 1x 0 | exit 2 | Almost the same |
| MAL_07 | exit 0 | 2x AV, 1x 0 | `-da` worsens termination |

EMPTY vs TMW0: 27/30 equal (loading TOMWare off ~= EmptyPin).
NAT vs TMW0: 21/30 equal. The MAL often go from NAT exit 0 to Pin exit 2.

## What may be written

External observation of output, exit code, children and files, on the NAT/EMPTY/TMW0/`-da` ladder.
On 3/5 BEN (05, 10, 14) TMW_ALL stdout and exit coincide with TMW0.
`-da` lengthens wall-clock (cost, not "gain").

## What must not be written

Behavioral equivalence, API traces, BBL coverage, "the countermeasures preserve fidelity".
FidelityProbe did not run (cannot coexist with TOMWare). No kernel ProcMon/ETW.
Do not mix with 155/155 nor with JCVHT.
