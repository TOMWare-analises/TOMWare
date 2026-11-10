# Audit of campaign corpus_aligned_10k (Stage 2)

The 9,000 raw JSON **were not altered**. This folder only contains reclassification and aggregates.

## Outcomes

- JSON: 9000 / expected 9000; unique triples: 9000.
- `raw crash=true`: 6517; of those, null `exit_code`: 6517.
- Reclassified to `exited_before_limit_exit_code_unknown`: 6517.
- True `exception_crash` (known exit code): 0.
- Cause: `Invoke-SingleRun.ps1` reads `$proc.ExitCode` after redirection; null compared with `< 0` becomes crash and `exception_code` `0x`.
- **Do not write** in the article that most short-lived samples crashed.

Persistent survival (window_controlled_termination / 250, Wilson 95%):

- Benign: NAT 8.0% [5.2, 12.0]; EMPTY 11.2%; TMW0 9.6%; TMW_DO 52.8% [46.6, 58.9]; TMW_ALL 56.4% [50.2, 62.4].
- Malicious: NAT 54.4% [48.2, 60.5]; EMPTY 32.4%; TMW0 32.8%; TMW_DO 57.6%; TMW_ALL 64.0% [57.9, 69.7].

NAT benign short: 20 runs with resources in only 2 of 25 binaries. EMPTY-NAT WS/CPU contrast in that stratum has n_pairs=2.

## Reclassification used

| audited_outcome | criterion |
|---|---|
| launch_failed | launch_success = false |
| timeout_expired | timeout = true |
| window_controlled_termination | persistent reached the end of the window |
| exited_before_limit_exit_code_unknown | crash=true and null exit_code and exception_code `0x` |
| exception_crash | crash=true with a known exit code |
| natural_exit | natural_completion without the artifact above |

## Resources

- Filter `sample_count > 0` is **post hoc**. It is not in `experiment.config.json`.
- Persistent wall-clock describes observed duration, not performance.
- `n_pairs_*` in the contrast tables is the effective n. Do not use `n_binaries = 25` when only 2 pairs have resources.

## Contrast that does NOT include zero (do not generalize as null)

- TMW_DM - TMW0, short malicious, WS: 0.451 MB 95%CI [0.049, 0.805] (n_pairs_ws=25; excludes zero=true).

## Forbidden phrases in this revision

- 31 binaries / 3100 launches / 10 s / 155/155 / -87% / -38% / 9/31.
- phrase: short-lived runs are mostly crash-exit.
- phrase: sample_count > 0 was fixed a priori in experiment.config.json.

Medians: conventional (mean of the two central values if n even). Bootstrap 2000, seed 705851366. Wilson 95% on proportions.
