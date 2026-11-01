# 22/30 diagnostic correction (Access)

Source: `experiment/results/oracles/fidelity_by_run.csv` (collector `Run-Fidelity.ps1`).
Derived: `experiment/results/oracles/fidelity_pairs_2230.csv`.

The collector already leaves `stdout_sha256` **empty** when `stdout_bytes=0`
(it does not write `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, the SHA-256 of a zero-length buffer).
The earlier insert that said “an empty stdout is hashed as the empty buffer” is withdrawn.

Agreement criterion (unchanged numerically): equal exit code **and** equal stdout hash field.
Two empty fields are equal fields, not equal hashes of empty buffers.

| Result | n |
|---|---|
| TMW0 vs TMW_ALL pairs | 30 |
| Agree | 22 |
| Disagree | 8 |
| Of the agrees: both stdout 0 bytes (empty hash field) | 12 |
| Of the agrees: non-empty stdout SHA-256 | 10 |
| Raw rows that stored SHA-256 of empty buffer | 0 |

Disagreements (exit differs; stdout field may still match):

| Sample | Rep | TMW0 exit | TMW_ALL exit | stdout bytes |
|---|---|---|---|---|
| BEN_06 | 1 | 3 | -2 | 0→0 |
| BEN_06 | 2 | 3 | -2 | 0→0 |
| BEN_06 | 3 | 3 | -2 | 0→0 |
| BEN_12 | 1 | 0 | -2 | 754→754 |
| BEN_12 | 2 | 0 | -2 | 754→754 |
| MAL_06 | 2 | 0 | 2 | 0→0 |
| MAL_07 | 1 | 0 | -1073741819 | 0→0 |
| MAL_07 | 2 | 0 | -1073741819 | 0→0 |

Do not call 22/30 behavioral fidelity. Empty-field agreement is an external observable only.
