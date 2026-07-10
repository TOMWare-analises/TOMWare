# Benchmark TOMWare â€” resumo

Gerado em: 2026-05-29 13:38:56

## Metadados

| Campo | Valor |
|-------|-------|
| Amostras no manifesto | 3 |
| Amostras encontradas | 6 |
| Cenarios por amostra | 2 |
| Timeout (s) | 120 |

## Resultados agregados

| Metrica | Valor |
|---------|-------|
| Linhas de resultado | 6 |
| Melhoria stealth vs baseline | 2 |

## Por amostra

| SHA-256 | Cenario | Outcome | Segundos | Exit | Melhoria |
|---------|---------|---------|----------|------|----------|| 0f20b0c906f3ad95... | pin_baseline | timeout | 120.059 | -2 | - |
| 0f20b0c906f3ad95... | pin_tomware_da | timeout | 120.013 | -2 | - |
| 36685efcf34c7a7a... | pin_baseline | complete | 4.02 |  | - |
| 36685efcf34c7a7a... | pin_tomware_da | complete | 57.268 |  | sim |
| 430b487c0bc9b533... | pin_baseline | complete | 17.489 |  | - |
| 430b487c0bc9b533... | pin_tomware_da | complete | 93.553 |  | sim |

## Proximos passos

1. Para amostras com melhoria, reexecutar com Contradef (scripts/run-contradef-tomware.ps1 -Mode trace).
2. Processar logs no FluxTrace e comparar com DBI-Log-Corpus.
3. Usar docs/TOMWARE-GUIA-COMPLETO.md para montagem do artigo e video.

