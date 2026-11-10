# TOMWare benchmark — summary

Generated at: 2026-05-29 13:38:56

## Metadata

| Field | Value |
|-------|-------|
| Samples in the manifesto | 3 |
| Samples found | 6 |
| Scenarios per sample | 2 |
| Timeout (s) | 120 |

## Aggregated results

| Metric | Value |
|--------|-------|
| Result rows | 6 |
| Stealth improvement vs baseline | 2 |

## Per sample

| SHA-256 | Scenario | Outcome | Seconds | Exit | Improvement |
|---------|---------|---------|----------|------|----------|
| 0f20b0c906f3ad95... | pin_baseline | timeout | 120.059 | -2 | - |
| 0f20b0c906f3ad95... | pin_tomware_da | timeout | 120.013 | -2 | - |
| 36685efcf34c7a7a... | pin_baseline | complete | 4.02 |  | - |
| 36685efcf34c7a7a... | pin_tomware_da | complete | 57.268 |  | yes |
| 430b487c0bc9b533... | pin_baseline | complete | 17.489 |  | - |
| 430b487c0bc9b533... | pin_tomware_da | complete | 93.553 |  | yes |

## Next steps

1. For samples with improvement, rerun with Contradef (scripts/run-contradef-tomware.ps1 -Mode trace).
2. Process logs in FluxTrace and compare with DBI-Log-Corpus.
3. Use docs/TOMWARE-GUIA-COMPLETO.md for article and video assembly.
