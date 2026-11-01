# Table 25 — `access_r43d_process_tree` (all 27; no cherry-pick)

DLL `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`. Launcher `C:\TOMWare\pin\pin.exe` `920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819`. N=3, elevated, 50 ms, snapshot `tomware_go`. `identified=false`. Persistence is not progress. `behavioral_progress_observed=false` on every row.

| Sample | Mode | Rep | Exit | Elapsed (ms) | 60 s alive | Named last | Named during | Progress |
|---|---|---|---|---|---|---|---|---|
| BEN_28 | Native | 1 | -1073741511 | 1687 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_28 | Native | 2 | -1073741511 | 250 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_28 | Native | 3 | -1073741511 | 266 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_28 | TMW0 | 1 | -1073741511 | 2265 | False | 6 | 3 | EXITED_BEFORE_WINDOW |
| BEN_28 | TMW0 | 2 | -1073741511 | 1875 | False | 0 | 3 | EXITED_BEFORE_WINDOW |
| BEN_28 | TMW0 | 3 | -1073741511 | 1500 | False | 6 | 3 | EXITED_BEFORE_WINDOW |
| BEN_28 | TMW_DO | 1 | -1 | 60281 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_28 | TMW_DO | 2 | -1 | 60235 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_28 | TMW_DO | 3 | -1 | 60250 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_46 | Native | 1 | -1073741511 | 188 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_46 | Native | 2 | -1073741511 | 188 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_46 | Native | 3 | -1073741511 | 187 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_46 | TMW0 | 1 | -1073741511 | 1375 | False | 6 | 3 | EXITED_BEFORE_WINDOW |
| BEN_46 | TMW0 | 2 | -1073741511 | 1375 | False | 6 | 3 | EXITED_BEFORE_WINDOW |
| BEN_46 | TMW0 | 3 | -1073741511 | 2157 | False | 0 | 3 | EXITED_BEFORE_WINDOW |
| BEN_46 | TMW_DO | 1 | -1 | 60312 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_46 | TMW_DO | 2 | -1 | 60297 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_46 | TMW_DO | 3 | -1 | 60203 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_47 | Native | 1 | -1073741511 | 203 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_47 | Native | 2 | -1073741511 | 203 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_47 | Native | 3 | -1073741511 | 203 | False | 0 | 0 | EXITED_BEFORE_WINDOW |
| BEN_47 | TMW0 | 1 | -1073741511 | 1609 | False | 0 | 3 | EXITED_BEFORE_WINDOW |
| BEN_47 | TMW0 | 2 | -1073741511 | 1672 | False | 0 | 3 | EXITED_BEFORE_WINDOW |
| BEN_47 | TMW0 | 3 | -1073741511 | 2938 | False | 6 | 3 | EXITED_BEFORE_WINDOW |
| BEN_47 | TMW_DO | 1 | -1 | 60156 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_47 | TMW_DO | 2 | -1 | 60172 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |
| BEN_47 | TMW_DO | 3 | -1 | 60187 | True | 6 | 3 | STILL_ALIVE_AT_WINDOW |

# Table 26 — cell medians of Table 25 (n=3). Interval = observed [min, max].

n=3 is too small for a bootstrap 95% CI. Median and the three-run range only.

| Sample | Mode | n | Median elapsed (ms) | Range (ms) | n alive 60 s | n named last |
|---|---|---|---|---|---|---|
| BEN_28 | Native | 3 | 266 | [250, 1687] | 0/3 | 0/3 |
| BEN_28 | TMW0 | 3 | 1875 | [1500, 2265] | 0/3 | 2/3 |
| BEN_28 | TMW_DO | 3 | 60250 | [60235, 60281] | 3/3 | 3/3 |
| BEN_46 | Native | 3 | 188 | [187, 188] | 0/3 | 0/3 |
| BEN_46 | TMW0 | 3 | 1375 | [1375, 2157] | 0/3 | 2/3 |
| BEN_46 | TMW_DO | 3 | 60297 | [60203, 60312] | 3/3 | 3/3 |
| BEN_47 | Native | 3 | 203 | [203, 203] | 0/3 | 0/3 |
| BEN_47 | TMW0 | 3 | 1672 | [1609, 2938] | 0/3 | 1/3 |
| BEN_47 | TMW_DO | 3 | 60172 | [60156, 60187] | 3/3 | 3/3 |

# Table 27 — guest Pin-without-Pintool only (campaign launcher)

Command: `C:\TOMWare\pin\pin.exe -- TestAntiDebug.exe`. Launcher `920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819`. Oracle `3B25069EEBC099593905F6075AF210E9DAE53AD405A5D98C3BB0DFCC0CE1CECD`. Host StartServer / `FBA632E4` as *launcher* is withdrawn. The engine file recorded beside the launcher is `intel64\bin\pin.exe` `FBA632E40F00FEEC1FAA7BC1A3BF8CC9A551AB1F17ABA6B07D31C67E602A741A`. That is not the command that was run.

| Rep | Launcher SHA-256 | Engine SHA-256 | Oracle SHA-256 | Exit | Duration (ms) | Timeout | Stderr | Conclusion |
|---|---|---|---|---|---|---|---|---|
| 1 | 920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819 | FBA632E40F00FEEC1FAA7BC1A3BF8CC9A551AB1F17ABA6B07D31C67E602A741A | 3B25069EEBC099593905F6075AF210E9DAE53AD405A5D98C3BB0DFCC0CE1CECD | 0 | 2963 | False | empty | completed_ok |
| 2 | 920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819 | FBA632E40F00FEEC1FAA7BC1A3BF8CC9A551AB1F17ABA6B07D31C67E602A741A | 3B25069EEBC099593905F6075AF210E9DAE53AD405A5D98C3BB0DFCC0CE1CECD | 0 | 1948 | False | empty | completed_ok |
| 3 | 920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819 | FBA632E40F00FEEC1FAA7BC1A3BF8CC9A551AB1F17ABA6B07D31C67E602A741A | 3B25069EEBC099593905F6075AF210E9DAE53AD405A5D98C3BB0DFCC0CE1CECD | 0 | 1900 | False | empty | completed_ok |
