# Stage 3 — collector v2.1

## What changed

- `Invoke-SingleRun.ps1`: launches the process with `System.Diagnostics.Process` (`Start-ObservedProcess`), not with `Start-Process -Redirect*`. `collector_version` = `2.1.0`.
- `ProcessCollector.ps1`: `Start-ObservedProcess` / `Complete-ObservedProcess`.
- `Run-MatchedOracles.ps1`: uses the same launcher. Timeout remains `-2` (runner code). No longer invents `-1`.
- Null `exit_code` is **not** a crash. Reason: `exited_before_limit_exit_code_unknown`.
- Crash only if `exit_code` is an integer `< 0` or `> 65535`.

## Host test (NAT, no Pin, no malware)

`exit_code_host_test.csv`:

| case | code | crash | reason |
|---|---|---|---|
| cmd exit 0 | 0 | false | natural_exit |
| cmd exit 1 | 1 | false | natural_exit |
| cmd exit 259 | 259 | false | natural_exit |
| null | (empty) | false | exited_before_limit_exit_code_unknown |

## What this does NOT do

- Does not reprocess or alter the 9000 JSON.
- Does not recover the exit codes of the old campaign.
- Confirmation of normal termination vs crash is left to Stage 7 (1800 runs with v2.1).
