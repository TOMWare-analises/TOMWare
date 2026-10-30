# NAT / EMPTY / TMW0 consolidated table

Source: `D:/MMB/workspace/tomware-melhorias/TOMWare/experiment/results/campaign/corpus_aligned_10k/sample_condition_medians.csv`. Not a rerun of the 9,000. Bootstrap 2000, seed 705851366.
Duration = median of per-binary medians. Paired delta = median of (A − B) within each binary.
CPU zeros are descriptive. NAT working-set/CPU cells are often empty (native collector).

| class | profile | n | NAT s | EMPTY s | TMW0 s | EMPTY−NAT s [CI] | TMW0−NAT s [CI] | TMW0−EMPTY s [CI] | NAT CPU n missing | NAT WS n missing |
|---|---|---:|---:|---:|---:|---|---|---|---:|---:|
| benign | short_lived | 25 | 0.26 [0.2537, 0.2718] | 1.4848 [1.2821, 2.8304] | 1.9735 [1.3977, 3.076] | 1.1656 [0.9554, 2.5527] (miss 0) | 1.2767 [1.0188, 2.4414] (miss 0) | 0.1506 [0.0259, 0.2702] (miss 0) | 23 | 23 |
| benign | persistent | 25 | 0.2543 [0.2503, 0.2594] | 2.1797 [1.3336, 4.0549] | 2.1897 [1.4648, 4.9628] | 1.165 [1.0647, 3.5655] (miss 0) | 1.4048 [1.1208, 4.0079] (miss 0) | 0.0491 [-0.0271, 0.1533] (miss 0) | 21 | 21 |
| malicious | short_lived | 25 | 6.1649 [0.7859, 120.682] | 10.332 [7.0185, 120.6522] | 14.0036 [7.4409, 120.6636] | 2.4303 [0.1852, 5.1551] (miss 0) | 2.4004 [0.0528, 4.1005] (miss 0) | -0.0299 [-0.1649, 0.189] (miss 0) | 4 | 4 |
| malicious | persistent | 25 | 60.6612 [1.585, 60.7194] | 13.2658 [6.5249, 35.3435] | 14.2779 [8.3603, 32.264] | 0.0125 [-6.7095, 0.9977] (miss 0) | 0.0258 [-44.0953, 1.659] (miss 0) | 0.1383 [0.0, 0.8947] (miss 0) | 5 | 5 |

Check (benign short-lived): NAT 0.260 s, EMPTY 1.485 s, TMW0 1.973 s from stratum medians 260.0 / 1484.8 / 1973.5 ms, n=25.
