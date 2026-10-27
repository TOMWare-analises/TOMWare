# Etapa 3 � coletor v2.1

## O que mudou

- `Invoke-SingleRun.ps1`: lanca o processo com `System.Diagnostics.Process` (`Start-ObservedProcess`), nao com `Start-Process -Redirect*`. `collector_version` = `2.1.0`.
- `ProcessCollector.ps1`: `Start-ObservedProcess` / `Complete-ObservedProcess`.
- `Run-MatchedOracles.ps1`: usa o mesmo lancador. Timeout continua a ser `-2` (codigo do runner). Nao inventa mais `-1`.
- `exit_code` nulo **nao** e crash. Motivo: `exited_before_limit_exit_code_unknown`.
- Crash so se `exit_code` for inteiro `< 0` ou `> 65535`.

## Teste host (NAT, sem Pin, sem malware)

`exit_code_host_test.csv`:

| caso | codigo | crash | motivo |
|---|---|---|---|
| cmd exit 0 | 0 | false | natural_exit |
| cmd exit 1 | 1 | false | natural_exit |
| cmd exit 259 | 259 | false | natural_exit |
| null | (vazio) | false | exited_before_limit_exit_code_unknown |

## O que isto NAO faz

- Nao reprocessa nem altera os 9000 JSON.
- Nao recupera os codigos de saida da campanha antiga.
- Confirmacao de termino normal vs crash fica para a Etapa 7 (1800 runs com v2.1).
