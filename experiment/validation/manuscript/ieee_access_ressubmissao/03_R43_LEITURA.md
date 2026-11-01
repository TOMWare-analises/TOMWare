# Leitura permitida — R4.3 process tree

Três campaign ids. Table 25 do artigo/carta usa **só** `access_r43b_process_tree`.
`access_r43c_process_tree` é evidência extra (N=3, elevação). **Não** colar r43c na Table 25.
`identified=false` em todas. Permanência ≠ progresso. Não reescreve as 9 000. Não é Arancino.

DLL: `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`.
Janela 60 s. N=1. Knobs: Native = (vazio); TMW0 = `-q`; TMW_DO = `-do -q`.
Snapshot `tomware_go`.

---

## A. Preserved: `access_r43_skewmask_diag` (29/10/2026)

Pasta no pack: `r43_skewmask_diag/`.

`process_tree.txt` em todas as nove: `tree_error` — `$pid` é variável automática só de leitura no PowerShell. A evidência de árvore nessa campanha é só `n_tree` no `resources.csv`. Não usar estes números como árvore pai/filho nomeada.

| sample | mode | progress | exit_code | elapsed_ms | peak_ws |
|---|---|---|---|---|---|
| BEN_28 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 1609 | 0 |
| BEN_28 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1687 | 70164480 |
| BEN_28 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61016 | 68624384 |
| BEN_46 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 781 | 0 |
| BEN_46 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1938 | 67272704 |
| BEN_46 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61234 | 68521984 |
| BEN_47 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 750 | 0 |
| BEN_47 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1703 | 71753728 |
| BEN_47 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61062 | 69128192 |

---

## B. Table 25: `access_r43b_process_tree` (30/10/2026, `script_rev=r43b.2`)

Pasta no pack: `r43b_process_tree/`. Script: `Run-AccessR43b.ps1` (`$procId`; CSV `name,pid,parent_pid,depth`).

SHA:
- BEN_28 `0111d485351ef0deffd9403a0f8e123759a04a928fbd055b901de18164c4fa39`
- BEN_46 `0ab9f2923dac072716a8380ec909ea9f74b9f1755f149c2a41f61b49d93633a2`
- BEN_47 `0abd30c5a4a6f17c9f1f718da42435ed05927a3c0ee5430a8ff337027f875dfd`

| sample | mode | progress | exit_code | elapsed_ms | peak_ws | named tree |
|---|---|---|---|---|---|---|
| BEN_28 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 3375 | 0 | none (`?` parent=-1) |
| BEN_28 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1625 | 65306624 | live `n_tree=3` then post-mortem `?` |
| BEN_28 | TMW_DO | EXITED_BEFORE_WINDOW | -1073741511 | 49344 | 79572992 | live `n_tree=3` ~49 s then dead. Not window fill |
| BEN_46 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 1155 | 0 | none |
| BEN_46 | TMW0 | EXITED_BEFORE_WINDOW | -1073741511 | 1625 | 73228288 | `pin.exe` → sample.exe + `conhost.exe` |
| BEN_46 | TMW_DO | STILL_ALIVE_AT_WINDOW | -1 | 61063 | 70381568 | same named tree |
| BEN_47 | Native | EXITED_BEFORE_WINDOW | -1073741511 | 437 | 0 | none |
| BEN_47 | TMW0 | EXITED_BEFORE_WINDOW | -1 | 719 | 10702848 | Pin fatal Win32 740 (elevation) |
| BEN_47 | TMW_DO | EXITED_BEFORE_WINDOW | -1 | 453 | 10829824 | Pin fatal Win32 740 (elevation) |

Árvore nomeada (BEN_46 TMW0 e TMW_DO), `process_tree.csv`:

```
name,pid,parent_pid,depth
pin.exe,<pid>,<parent>,0
0ab9f2923dac072716a8380ec909ea9f74b9f1755f149c2a41f61b49d93633a2.exe,<pid>,<pin>,1
conhost.exe,<pid>,<pin>,1
```

BEN_47 TMW0/TMW_DO `stdout.txt` / `drop/pin.log`: `System error 740 : A operação solicitada requer elevação.` Isto **não** é `STATUS_ENTRYPOINT_NOT_FOUND` e **não** é um hold do SkewMask.

N=1. Tempos Native/TMW0 diferem da campanha r43; não misturar as duas tabelas.

---

## C. Extra only: `access_r43c_process_tree` (31/10/2026, `script_rev=r43c.1`)

Pasta no pack: `r43c_process_tree/`. **Não é Table 25.** N=3, sessão elevada, sample 50 ms, primeiro sample imediato. 27/27 retidas.

Pin hashed nas células TMW0/TMW_DO: `FBA632E4…741A` = `pin\intel64\bin\pin.exe`. **Não** é o launcher documentado `pin\pin.exe` `920A730A…0BB819` (`pin_sha256_matches_campaign=false`).

| Cell | n | Exit | 60 s alive | Named last dump |
|---|---|---|---|---|
| Native × 9 | 9 | all `−1073741511` in 107–813 ms | 0/9 | 0/9 |
| TMW0 × 9 | 9 | all `−1073741511` in 938–1360 ms | 0/9 | 4/9 |
| TMW_DO × 9 | 9 | 8× `−1073741511` at 41–59 s; 1× STILL_ALIVE BEN_47 r1 60062 ms | **1/9** | 3/9 |

Named last (`pin.exe` → sample + `conhost.exe`): TMW0 BEN_46 r1, BEN_47 r1/r2; TMW_DO BEN_28 r2/r3, BEN_47 r1. `process_events.jsonl` can show pin+PE during the window even when the last dump is `?`.

BEN_47 sob elevação lançou. O Win32 740 do r43b **não** voltou. Native BEN_47 = o mesmo `STATUS_ENTRYPOINT_NOT_FOUND` que BEN_28/46.

`behavioral_progress_observed=false` nas 27. `identified=false`. 1/9 vivo ≠ progresso. Guest Pin-without-tool N=3 não foi copiado; incompatibilidade **não** confirmada.

---

## Interpretação permitida

1. Nestes três SHA, no snap `tomware_go`, o nativo **não entra** (`STATUS_ENTRYPOINT_NOT_FOUND`). Não é “persistente a trabalhar”.
2. Na Table 25 (r43b) a única árvore pai/filho **nomeada** no dump final é BEN_46: launcher Pin, PE alvo, `conhost.exe`.
3. TMW_DO BEN_46 r43b preenche a janela de 60 s com essa árvore. Isso é espera/estado, não GUI recuperada.
4. TMW_DO BEN_28 r43b teve árvore viva ~49 s e depois o mesmo exit de entrada. Não contar como `STILL_ALIVE`.
5. BEN_47 r43b sob Pin falhou ao lançar (UAC/elevação). No r43c, com elevação, o 740 não voltou; isso **não** promove r43c a Table 25.
6. r43c: 1/9 TMW_DO vivo (BEN_47 r1) e árvores nomeadas intermitentes. Permanência / Pin vivo ≠ progresso.
7. Sem traces de API não se distingue “o alvo correu” de “o Pin ficou vivo”. Classificar **inconclusivo** quanto a progresso.
8. Dois `pin.exe`: `920A730A` (campanha documentada) ≠ `FBA632E4` (r43c / host intel64). Não fundir as identidades.

## O que isto não é

Não é bake-off Arancino. Não é prova de checagem evasiva. Não reescreve Table 19. Não é equivalência de API. Não é o demonstrador JCVHT `TestRecoverWork`. Não é 155/155 nem −87,2 %.
