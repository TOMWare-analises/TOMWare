# Leitura permitida — access_r43_skewmask_diag

Data das corridas: 29/10/2026, guest `tomware_go`, host `C:\Users\marge\Downloads\access_r43`.
DLL em todos os `run_meta.json`: `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`.
Janela 60 s. N=1. Knobs: Native = (vazio); TMW0 = `-q`; TMW_DO = `-do -q`.
`identified=false` nas nove.

O consola do TMW_DO imprimiu `exit=0` enquanto o Pin ainda estava vivo. Depois do `Stop-Process` o JSON ficou `timed_out=true`, `exit_code=-1`. **Usar o JSON.**

## Tabela (run_meta.json)

| sample | sha256 | mode | progress | timed_out | exit_code | elapsed_ms | peak_ws (bytes) |
|---|---|---|---|---|---|---|---|
| BEN_28 | 0111d485351ef0deffd9403a0f8e123759a04a928fbd055b901de18164c4fa39 | Native | EXITED_BEFORE_WINDOW | false | -1073741511 | 1609 | 0 |
| BEN_28 | …fa39 | TMW0 | EXITED_BEFORE_WINDOW | false | -1073741511 | 1687 | 70164480 |
| BEN_28 | …fa39 | TMW_DO | STILL_ALIVE_AT_WINDOW | true | -1 | 61016 | 68624384 |
| BEN_46 | 0ab9f2923dac072716a8380ec909ea9f74b9f1755f149c2a41f61b49d93633a2 | Native | EXITED_BEFORE_WINDOW | false | -1073741511 | 781 | 0 |
| BEN_46 | …33a2 | TMW0 | EXITED_BEFORE_WINDOW | false | -1073741511 | 1938 | 67272704 |
| BEN_46 | …33a2 | TMW_DO | STILL_ALIVE_AT_WINDOW | true | -1 | 61234 | 68521984 |
| BEN_47 | 0abd30c5a4a6f17c9f1f718da42435ed05927a3c0ee5430a8ff337027f875dfd | Native | EXITED_BEFORE_WINDOW | false | -1073741511 | 750 | 0 |
| BEN_47 | …5dfd | TMW0 | EXITED_BEFORE_WINDOW | false | -1073741511 | 1703 | 71753728 |
| BEN_47 | …5dfd | TMW_DO | STILL_ALIVE_AT_WINDOW | true | -1 | 61062 | 69128192 |

`resources.csv` Native: `root_alive=0`, `n_tree=0` na primeira amostra (~300 ms).
TMW0: `n_tree=3` e dezenas de MB, depois `root_alive=0` antes de 2 s.
TMW_DO: `n_tree=3`, `root_alive=1` até ~60 000 ms; `root_cpu_ms` final ≈ 12 609 / 13 516 / 12 578.

`process_tree.txt` em todas: `tree_error` — `Não é possível substituir a variável PID porque ela é somente leitura ou constante.` (bug do script: `$pid` automático). A evidência de árvore é só `n_tree` no CSV.

`stdout.txt` / `stderr.txt`: vazios nas nove.

## Interpretação permitida

1. Nestes três SHA, no snap `tomware_go`, o nativo **não entra** (`STATUS_ENTRYPOINT_NOT_FOUND`). Não é “persistente a trabalhar”.
2. TMW0 não muda o exit; só acrescenta o WS do Pin.
3. TMW_DO mantém o processo raiz (Pin) até a janela administrativa. Isso **reproduz** o padrão das medianas 9 000 (TMW0 ~1,3–1,6 s, TMW_DO ~60,8 s) como **espera/estado**, não como GUI recuperada.
4. Sem traces de API não se distingue “o alvo correu 60 s” de “o Pin ficou vivo”. Classificar **inconclusivo** quanto a progresso.

## O que isto não é

Não é bake-off Arancino. Não é prova de checagem evasiva. Não reescreve Table 19. Não é equivalência de API. Não é o demonstrador JCVHT `TestRecoverWork`.
