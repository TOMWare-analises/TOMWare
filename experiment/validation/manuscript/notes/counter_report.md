# Etapa 5 � relatorio dos contadores

Fonte: `Downloads\etapa5_counters` copiada para `05_counters/from_vm/`.
DLL: live-dump `3A3AFB6FF2964EBFF82958911EE32F31B5C5E5AAD74F289D9A1B9A0BCFA51FC0`
(nao e a DLL da campanha 9000 `4bbc6270...`). Timeout 45 s. 30 PE x 2 bracos x 10 = 600.

## Cobertura

| | n | json=1 | json=0 |
|---|---|---|---|
| Total | 600 | 537 | 63 |
| BEN | 300 | 300 | 0 |
| MAL | 300 | 237 | 63 |
| TMW0_COUNT | 300 | 268 | 32 |
| TMW_ALL_COUNT | 300 | 269 | 31 |

json=0 concentrado: MAL_13, MAL_14, MAL_15 (20/20 cada, exit `0xC000012F`) e 3 runs de MAL_12.
Nao inventar contagens para esses 63. TMW0 sem JSON e o mesmo trio.

## Controlo TMW0 (modulos desligados)

268 JSON. Superficies AD/PE/ENV/MC/SK = **0**. O `-mc` grava o ficheiro; nada dispara. Controlo negativo OK.

## TMW_ALL (so runs com JSON)

269 JSON (150 BEN + 119 MAL).

| Modulo | surf | trig | mod | Leitura |
|---|---|---|---|---|
| AntiDebug | 269/269 | 269 | 269 | `-da` sanitiza PEB na carga. Nao prova que a amostra chamou IsDebuggerPresent. |
| SanitizeEnv | 259/269 | 259 | 259 | 10 falhas: so MAL_08 (env_found=env_sanitized). |
| InstMemcmp | 146/269 | 0 | 0 | Comparacoes existem; **0** assinaturas PIN_/pin.exe. Nao afirmar que escondeu Pin. |
| SkewMask | 39/269 | 39 | 39 | BEN_06 (10/10); MAL_03 (10); MAL_07 (10); MAL_10 (9). |
| ProcessEnum | 0/269 | 0 | 0 | Nenhum destes 30 PE chamou Process32*/Module32*. |

## O que nao se pode escrever

- "O malware usou as 5 verificacoes."
- "SkewMask always hides Pin."
- Superioridade sobre Arancino.
- Contagens para MAL_13/14/15.
- Misturar esta DLL com a campanha 9000.

## Exits (nao descartar)

`0xC0000135` DLL_NOT_FOUND (varios BEN). `0xC0000139` ENTRYPOINT_NOT_FOUND (BEN_08).
`0xC0000005` AV (MAL_09 e alguns). `-2` timeout do runner (MAL_03/04/08/10/12).
`-1` sem codigo (BEN_02, MAL_05). `0xC000012F` INVALID_VIEW_SIZE (MAL_13/14/15).

## Ficheiros

- `from_vm/module_events_by_run.csv` (600 linhas)
- `from_vm/raw_json/` (538 JSON)
