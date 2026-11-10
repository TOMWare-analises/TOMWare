# Stage 7 — prospective exit-code confirmation (collector v2.1)

Source: `Downloads\etapa7_confirm\exitcodes_by_run.csv` -> `07_confirm/from_vm/`.
Snapshot DLL `4BBC6270`. `collector_version=2.1.0`. 20 short PE x 9 arms x 10 = **1800/1800**.
Timeout 45 s. Does not rewrite the 9000 JSON.

## Coverage

| | n |
|---|---|
| Unique runs | 1800 |
| Integer exit captured | 1600 (88.9%) |
| Null exit | 200 (11.1%) |
| Timeout (`-2`) | 218 |
| `natural_exit` (0..65535) | 491 |
| `exception_crash` (v2.1 rule: integer <0 or >65535, except `-2`) | 891 |

Duration: min 22 ms, median 2644 ms, max 49448 ms. Not an empty CSV: Pin ran.

## What this answers

In the 9000 campaign, 6517 `exception_crash` were **null exit** (collector bug). Here v2.1 fills the code on most runs.
The 9000 are not reclassified. The article sentence: the 6517 remain "termination without a code"; this stage is **new confirmation**.

## Break down the 891 "crash"

They are not 891 TOMWare failures. NAT alone already has 83. Codes:

| exit | NTSTATUS | n | Reading |
|---|---|---|---|
| -1073741515 | `0xC0000135` DLL_NOT_FOUND | 442 | Load (BEN_01/03/04/07/09). Also on NAT. |
| -1 | (sentinel) | 248 | BEN_02 and MAL_05: 90/90. Not AV. |
| -1073741819 | `0xC0000005` ACCESS_VIOLATION | 105 | Mainly MAL_09; some MAL_03/07. |
| -1073741511 | `0xC0000139` ENTRYPOINT | 90 | BEN_08 90/90. |
| other NTSTATUS | | 6 | MAL_04 |

True AV: **105/1800 (5.8%)**, not 72%.

## Nulls (200)

BEN_10: 90/90 without a code (in Stage 6 this PE gave exit 0). MAL_07 72, MAL_06 18, MAL_01 10, MAL_09 9. v2.1 does **not** close 100% of cases. The rule remains: null != crash.

## Natural exit (491)

BEN_05: 90/90 exit 1. BEN_06: 90/90 exit 3.
MAL_01/02/06/08: majority exit 1 or 2, stable between TMW0 and TMW_ALL.

## What must not be written

155/155, "short-lived runs are mostly crash-exit" as in the old campaign,
"891 crashes caused by Pin", mixing these 1800 with the 9000.
