# Inventario � evidencia existente / acao minima / saida esperada

Congelado em 2026-10-22T17:20:41Z.
Catalogo dos 9000 JSON: `raw_runs_sha256.csv` (merkle `382f98e25fb46e95f168f7df0283175ebd067835d5760c10f60c2c12f14398ae`).
DLL da campanha = DLL do host: `4bbc62707ee0b2ef922d4e8659a6392d92814ea0fc74f4682f1187562ae7f0e6`.
EmptyPinTool: `804be19bf7924b641fe25f07ea89dec26dc9daa36c49638f407ff96e2ab153c8`.
Pin: 3.28.98749. Semente: 705851366.

| ID | Evidencia existente | Acao minima | Saida esperada | Estado |
|---|---|---|---|---|
| E0 | PDF Overleaf = revisao de 13/10 (hash `0FEF4163...`) | Nao editar o PDF agora; no fim um unico PDF de instrucoes | Overleaf so muda depois das etapas VM + valores finais | feito |
| E1 | Protocolo, config, scripts, corpus, fontes C++, 9000 JSON | Hash SHA-256, nao alterar brutos | `frozen_manifest.csv` | feito |
| E2 | 9000 JSON; 6517 `exception_crash` com `exit_code` nulo | Reclassificar sem gravar por cima | `02_audit/*` | feito |
| E3 | `Invoke-SingleRun.ps1` e `Run-MatchedOracles.ps1` perdem ExitCode | Corrigir captura; teste NAT com saidas 0, 1 e excecao | protocolo v2; campanha antiga nao e reprocessada com v2 | pendente |
| E4a | AntiDebug: 1 run por condicao no CSV de 21/10 | 3 repeticoes NAT / TMW0 / TMW `-dd` com `-gdb` | CSV 3+3 | VM |
| E4b | Timing N=30 (90 linhas) | Manter; registrar proveniencia | hash `76208218...` ja no manifesto | feito (nao repetir) |
| E4c | Probe Pin sem `-t` (`pin_condition_valid=false`) | Registrar saida e motivo | nota de bloqueio | VM ou log existente |
| E4d | `-da` nos 5 oraculos: PE_da e DA_overhead existem; AD/EV/MS incompletos | Completar `-da` nos 5 | CSV | VM |
| E4e | TestConcurrentWaits / Module32: nativo OK; Pin timeout -2 | Controlo positivo EmptyPin + timeout declarado | CSV | VM |
| E5 | `ModuleCounters.cpp` e knobs `-mc`/`-mcf` no codigo; `module_counters.enabled=false` | 600 runs diagnosticos TMW0_COUNT / TMW_ALL_COUNT | `module_events_by_run.csv` | VM |
| E6 | `FidelityProbe` e outro pintool | Observacao externa (ProcMon/ETW), 120 runs | dossie de fidelidade | VM; precisa aval do coautor |
| E7 | Codigo de saida dos 9000 nao e recuperavel | 1800 runs com coletor v2 | confirmacao prospectiva | VM |
| E8 | Arancino ausente do repo | Verificar Pin 2.x / x86 vs Pin 3.28 x64 | bake-off ou bloqueio documentado | **bloqueio** 23/10; `08_arancino/BLOQUEIO.md` |
| E9 | `corpus.csv` tem SHA-256, grupo, perfil; familia generica | Metadados so de PE header / fonte verificavel | `MANUSCRIPT_VALUES.json` | **OK** 23/10; `09_values/` |
| E10 | Cartas EN/PT atuais tem erros | Regenerar so no fim | PDF unico Overleaf + cartas | fim |

## Numeros ja auditados (usar estes, nao os do PDF)

Desfechos (n=250 por celula):

- Benigno persistente, sobrevivencia na janela: NAT 8.0% [5.2, 12.0]; EMPTY 11.2%; TMW0 9.6%; TMW_DO 52.8% [46.6, 58.9]; TMW_ALL 56.4% [50.2, 62.4].
- Maligno persistente: NAT 54.4% [48.2, 60.5]; EMPTY 32.4%; TMW0 32.8%; TMW_DO 57.6%; TMW_ALL 64.0% [57.9, 69.7].
- `natural_exit` = 0. `exception_crash` verdadeiro = 0. Os 6517 sao termino antes do limite com codigo desconhecido.
- NAT benigno curto: so 2 de 25 binarios tem recursos (`n_pairs_ws=2` no contraste EMPTY-NAT). Nao publicar essa celula como n=25.
- TMW_DM ? TMW0, malignos curtos, WS: +0.451 MB [0.049, 0.805], n_pairs=25. IC nao inclui zero.

Timing N=30 (medianas convencionais): TMW0 2433.285; GO 3083.210 (11/30 abaixo); GO_DO 2104.770 (30/30). Wilson 11/30 = 21.87�54.49%; 30/30 = 88.65�100%.
