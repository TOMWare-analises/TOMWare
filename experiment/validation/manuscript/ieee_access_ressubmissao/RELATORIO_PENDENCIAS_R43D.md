# Short report — Access r43d + pin-bare N=3 (31 Oct 2026)

Not the article. Not IEEE. Does not rerun the 9,000.

## Confirmed

**Pin without Pintool (Table 27).** Guest `C:\TOMWare\pin\pin.exe -- TestAntiDebug.exe`, N=3, snapshot `tomware_go`.

| Field | Value |
|---|---|
| Launcher | `920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819` |
| Engine file recorded | `intel64\bin\pin.exe` `FBA632E4…741A` (not the command that was run) |
| Oracle | `3B25069EEBC099593905F6075AF210E9DAE53AD405A5D98C3BB0DFCC0CE1CECD` |
| Pin version | 3.28.98749 |
| Exit / timeout / stderr | 0 / false / empty on 3/3 |
| Duration | 2963 / 1948 / 1900 ms |
| Stdout | oracle OK; PEB fields 0 |

Classification: **technically valid on the campaign launcher; omitted from the 9,000 by design.** Incompatibility is **not** confirmed. Host StartServer is not this result. `campaign.json` `pin_condition_valid=false` was not flipped.

**Process trees (Tables 25–26).** `access_r43d_process_tree`, script `r43d.1`, 27/27 kept, elevated, 50 ms, DLL `4BBC6270`, launcher `920A730A` (`pin_sha256_matches_campaign=true`).

| Cell | Result |
|---|---|
| Native × 9 | all `−1073741511` (`STATUS_ENTRYPOINT_NOT_FOUND`), 187–1687 ms, no named last dump |
| TMW0 × 9 | all `−1073741511`, 1375–2938 ms; named last dump 5/9 |
| TMW_DO × 9 | all `STILL_ALIVE_AT_WINDOW` ~60.2 s; named last dump 9/9 |

Named last tree (when present): `pin.exe` → `pin.exe` → `pin.exe` + sample.exe + two `conhost.exe`. That chain is the campaign launcher wrapping the engine; it is not recovered GUI/application progress.

`behavioral_progress_observed=false` on all 27. `identified=false`. TMW_DO 9/9 alive is wait/state under `-do`, not a gain.

Preserved, not Table 25: r43 (`tree_error`), r43b (N=1, BEN_47 = Pin 740), r43c (launcher `FBA632E4`).

**22/30.** Unchanged 22 agree / 8 disagree. 0-byte stdout keeps an empty hash field (12 of the 22 agrees). Not SHA-256 of the empty buffer.

## Inconclusive / not claimed

- Native last dumps are `?` because the PE died before a named CIM sample.
- Four TMW0 last dumps are `?` even though `process_events.jsonl` saw pin+PE during the window.
- No API traces: a live Pin tree is not “the target made progress.”
- n=3: Table 26 reports median and [min, max], not a bootstrap 95% CI.
- Engine file `FBA632E4` exists beside the launcher; Table 27’s command is still `pin\pin.exe`.

## Files

- Raw: `experiment/results/oracles/access_r43d/` (27) and `experiment/results/oracles/guest/pin_bare_guest_n3/` (3)
- CSV: `access_r43d_summary.csv`, `access_r43d_cell_medians.csv`, `pin_bare_guest_n3_summary.csv`, `fidelity_pairs_2230.csv`
- Excerpts: `TABELAS_25_26_27_R43D.md`, `CORRECAO_22_30.md`
- Manifest: `experiment/results/oracles/r43d_ingest_manifest.json`

## Still limitations (not run)

Full temporal coherence; interface matrix / new DLL versus the 9,000; paired behavioural traces; malware check–branch–recovered-behavior case; Arancino / COBAI / Peekaboo bake-off.
