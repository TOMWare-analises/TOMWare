# Etapa 7 � confirmacao prospectiva de exit code (coletor v2.1)

Fonte: `Downloads\etapa7_confirm\exitcodes_by_run.csv` -> `07_confirm/from_vm/`.
DLL snapshot `4BBC6270`. `collector_version=2.1.0`. 20 PE curtos x 9 bracos x 10 = **1800/1800**.
Timeout 45 s. Nao reescreve os 9000 JSON.

## Cobertura

| | n |
|---|---|
| Runs unicos | 1800 |
| Exit inteiro capturado | 1600 (88.9%) |
| Exit nulo | 200 (11.1%) |
| Timeout (`-2`) | 218 |
| `natural_exit` (0..65535) | 491 |
| `exception_crash` (regra v2.1: inteiro <0 ou >65535, excepto `-2`) | 891 |

Duracao: min 22 ms, mediana 2644 ms, max 49448 ms. Nao e CSV vazio: o Pin correu.

## O que isto responde

Na campanha 9000, 6517 `exception_crash` eram **exit nulo** (bug do coletor). Aqui o v2.1 preenche o codigo na maioria dos runs.
Nao se reclassificam os 9000. A frase do artigo: os 6517 continuam "termino sem codigo"; esta etapa e **confirmacao nova**.

## Desdobrar os 891 "crash"

Nao sao 891 falhas da TOMWare. NAT sozinho ja tem 83. Codigos:

| exit | NTSTATUS | n | Leitura |
|---|---|---|---|
| -1073741515 | `0xC0000135` DLL_NOT_FOUND | 442 | Carga (BEN_01/03/04/07/09). Tambem no NAT. |
| -1 | (sentinela) | 248 | BEN_02 e MAL_05: 90/90. Nao e AV. |
| -1073741819 | `0xC0000005` ACCESS_VIOLATION | 105 | Principalmente MAL_09; alguns MAL_03/07. |
| -1073741511 | `0xC0000139` ENTRYPOINT | 90 | BEN_08 90/90. |
| outros NTSTATUS | | 6 | MAL_04 |

AV verdadeiro: **105/1800 (5.8%)**, nao 72%.

## Nulos (200)

BEN_10: 90/90 sem codigo (na Etapa 6 este PE deu exit 0). MAL_07 72, MAL_06 18, MAL_01 10, MAL_09 9. O v2.1 **nao** fecha 100% dos casos. Continua a regra: nulo != crash.

## Natural exit (491)

BEN_05: 90/90 exit 1. BEN_06: 90/90 exit 3.
MAL_01/02/06/08: maioria exit 1 ou 2, estavel entre TMW0 e TMW_ALL.

## O que nao se pode escrever

155/155, "short-lived runs are mostly crash-exit" como na campanha antiga,
"891 crashes causados pelo Pin", misturar estes 1800 com os 9000.
