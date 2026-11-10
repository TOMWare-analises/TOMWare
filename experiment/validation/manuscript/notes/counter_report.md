# Stage 5 — counter report

Source: `Downloads\etapa5_counters` copied to `05_counters/from_vm/`.
DLL: live-dump `3A3AFB6FF2964EBFF82958911EE32F31B5C5E5AAD74F289D9A1B9A0BCFA51FC0`
(not the 9000-campaign DLL `4bbc6270...`). Timeout 45 s. 30 PE x 2 arms x 10 = 600.

## Coverage

| | n | json=1 | json=0 |
|---|---|---|---|
| Total | 600 | 537 | 63 |
| BEN | 300 | 300 | 0 |
| MAL | 300 | 237 | 63 |
| TMW0_COUNT | 300 | 268 | 32 |
| TMW_ALL_COUNT | 300 | 269 | 31 |

json=0 concentrated: MAL_13, MAL_14, MAL_15 (20/20 each, exit `0xC000012F`) and 3 runs of MAL_12.
Do not invent counts for those 63. TMW0 without JSON is the same trio.

## TMW0 control (modules off)

268 JSON. Surfaces AD/PE/ENV/MC/SK = **0**. `-mc` writes the file; nothing fires. Negative control OK.

## TMW_ALL (only runs with JSON)

269 JSON (150 BEN + 119 MAL).

| Module | surf | trig | mod | Reading |
|---|---|---|---|---|
| AntiDebug | 269/269 | 269 | 269 | `-da` sanitizes the PEB at load. Does not prove the sample called IsDebuggerPresent. |
| SanitizeEnv | 259/269 | 259 | 259 | 10 failures: MAL_08 only (env_found=env_sanitized). |
| InstMemcmp | 146/269 | 0 | 0 | Comparisons exist; **0** PIN_/pin.exe signatures. Do not claim it hid Pin. |
| SkewMask | 39/269 | 39 | 39 | BEN_06 (10/10); MAL_03 (10); MAL_07 (10); MAL_10 (9). |
| ProcessEnum | 0/269 | 0 | 0 | None of these 30 PE called Process32*/Module32*. |

## What must not be written

- "The malware used the 5 checks."
- "SkewMask always hides Pin."
- Superiority over Arancino.
- Counts for MAL_13/14/15.
- Mixing this DLL with the 9000 campaign.

## Exits (do not discard)

`0xC0000135` DLL_NOT_FOUND (several BEN). `0xC0000139` ENTRYPOINT_NOT_FOUND (BEN_08).
`0xC0000005` AV (MAL_09 and some). `-2` runner timeout (MAL_03/04/08/10/12).
`-1` no code (BEN_02, MAL_05). `0xC000012F` INVALID_VIEW_SIZE (MAL_13/14/15).

## Files

- `from_vm/module_events_by_run.csv` (600 lines)
- `from_vm/raw_json/` (538 JSON)
