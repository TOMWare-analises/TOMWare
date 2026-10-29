# Resposta a cada item do briefing Access-2026-38745

29/10/2026. Só números que estão nos CSV/JSON deste pacote ou no repositório citado. Campanha do artigo = 100 PE × 9 × 10 = 9 000. DLL `4BBC6270…F0E6`. Pin 3.28.98749. Snapshot `tomware_go`. Semente 705851366. **Não** é a campanha JCVHT (31 PE / 10 s / 3 100).

Os seis pareceres descrevem o manuscrito antigo (31/3 100/10 s, AntiDebug não pareado, 9/31, −87,2 %). O PDF atual (`Access-2026-38745_CURRENT.pdf`, SHA-256 `5CBC8E96…A98020`, 22 pp) **já não é esse texto**. As 9 000 tentativas **não foram refeitas**. Os JSON brutos **não foram reescritos**.

---

## Item 1 — Auditar e corrigir o coletor

**Pedido.** Investigar as 6 517 com código de saída indisponível e os CPU a zero; distinguir launcher / alvo / filhos; gravar PID, relógio externo, exit real (incluindo 0); separar lançamento, erro de coleta, status desconhecido, timeout e janela; não transformar o antigo em sucesso ou crash.

**O que existe (preservado).**

| Facto | Ficheiro | Número |
|---|---|---|
| JSON / triples / esperados | `evidencias/completeness.json` | 9 000 / 9 000 / 9 000; duplicados 0 |
| `crash_exit` bruto | o mesmo | 6 517, **todos** com `exit_code` nulo |
| Crash verdadeiro com código conhecido | `evidencias/campaign_audit_report.md` | **0** |
| Reclassificação (sem gravar por cima) | o mesmo | `exited_before_limit_exit_code_unknown` |
| Condições | completeness | 9 × 1 000 (NAT, EMPTY, TMW0, TMW_DD/DP/DE/DM/DO, TMW_ALL) |

Causa: `Invoke-SingleRun.ps1` lia `$proc.ExitCode` após redirect. Em PowerShell 5.1 o nulo comparado com `< 0` virava `exception_crash` / `exception_code=0x`.

**Correção no código (campanhas novas, não as 9 000).** `Get-SafeProcessExitCode` em `scripts/Invoke-SingleRun.ps1` (coletor v2.1): `Refresh`, `HasExited`, segundo `WaitForExit()` sem timeout. Confirmado na Etapa 7: 1 800 runs, 1 600 (88,9 %) com exit inteiro; AV verdadeiro `0xC0000005` = 105/1 800, não 72 %. Relatório: `evidencias/exitcode_report.md`. Identificador próprio; JSON das 9 000 intactos.

**Sub-pedidos, estado.**

| Sub-pedido | Estado | Evidência |
|---|---|---|
| Distinguir launcher Pin / alvo / descendentes | Parcial nas 9 000; R4.3 tem `n_tree` e WS raiz vs árvore | `r43_skewmask_diag/*/resources.csv`. `process_tree.txt` **falhou** (`$pid` é variável automática só de leitura no PowerShell) |
| PID, identificação temporal, relações | Parcial | `resources.csv`: utc ISO, elapsed_ms, root_alive, n_tree. Árvore nominativa ausente no R4.3 |
| Código de saída real, incluindo zero | 9 000: 6 517 nulos preservados. R4.3 Native/TMW0: **−1073741511**. TMW_DO após corte: **−1** (`timed_out=true`) | `run_meta.json` |
| Separar lançamento / coleta / desconhecido / timeout / janela | Sim, na reclassificação auditada | `campaign_audit_report.md` tabela `audited_outcome` |
| CPU zero ≠ CPU indisponível | Parcial | Medianas 9 000 ainda trazem 0.0 em vários braços; R4.3 TMW_DO `root_cpu_ms` ≈ 12,5–13,5 s / 60 s |
| Memória em bytes e conversão | R4.3 em bytes (`peak_ws`). Campanha em MiB (`med_ws_mb`) | Não misturar unidades |
| Pico = contador do sistema ou max das amostras | R4.3 = **máximo das amostras** (~200 ms) | `tree_ws_peak` |
| Duração por relógio externo | Sim | `Get-Date` em `Measure-Window` |
| Processos residuais | R4.3 mata `pin.exe` / `pinbin.exe` entre modos | `Stop-Leftovers`; restore `tomware_go` entre modos |
| Validar coletor com oráculos controlados (exit 0, ≠0, curto, CPU, espera, filho) | **Não feito como bateria dedicada neste ensaio** | Etapa 7 usou 20 PE curtos reais; R4.3 usou 3 GUI persistentes do corpus |

**Não declarar atendido:** as 6 517 não são sucesso nem crash. O PDF atual já recusa taxa de sucesso a partir delas.

---

## Item 2 — Completar a validação funcional

Para cada teste: referência, tratamento, esperado, observado, N fixo, comando, logs. TMW_ALL no corpus **não** substitui esta bateria.

### AntiDebug — atendido no alcance declarado

Seis registros pareados + nativos: `evidencias/antidebug_n3.csv`.

- NAT e TMW0 (`-q`): PEB.BeingDebugged = 0, NtGlobalFlag = 0, exit 0 (3+3).
- `-gdb -q`: IsDebuggerPresent / PEB.BeingDebugged / PEB.NtGlobalFlag = 1 (3/3).
- `-gdb -dd -q`: os três voltam a 0 (3/3).

`-gdb` é **oráculo de PEB**, não depurador anexado. CheckRemoteDebuggerPresent / ProcessDebugPort / ProcessDebugObjectHandle ficaram 0 em todos os braços deste CSV — não foram o estímulo. Limitar o texto aos campos exercitados.

### ProcessEnum — parcial

`evidencias/processenum_base.csv` (Toolhelp imagem `pin.exe`): NAT 0, TMW0 **3**, `-dp` 0, `-da` 0.

Fixture Module32 (cópia de `version.dll` chamada `pinvm.dll`, **não** é o Pin real): `evidencias/module32_fixture.csv` — `-dp`/`-da` removem o nome pin-ish; término `ENUM_OK`. Não substitui `NtQuerySystemInformation`. Variantes ANSI/Unicode de Process32/Module32/GetModuleHandle **não** estão todas nesta bateria.

### SanitizePinEnvVars — parcial (oráculo `-da`)

`evidencias/da_n10.csv` linha `DA3_EV` (`TestGetEnvironments.exe`, `-da -q`): PIN_APP/VM_LD_LIBRARY_PATH e PIN_CRT_TZDATA = 0, exit 0. Não é prova de todas as consultas Windows/CRT nem do layout de ambiente fora deste oráculo.

### InstMemcmpMask — parcial

`evidencias/memcmp_n10.csv` (campanha `t2_n10_v7b`, DLL de campanha `4BBC6270`):

- `memcmp` / `_memicmp` / `RtlCompareMemory`: PASS na referência, MASKED com `-dm`/`-da`.
- Igualdade legítima e pass-through de desigualdade: OK nas linhas.
- `RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `wmemcmp_s`, `bcmp`: ABSENT / NOT_EXERCISED.
- `_memicmp_l` (3 argumentos) na DLL de campanha: ACCESS_FAULT conhecido. O arranjo de 4 argumentos é **outra** DLL (`D55EC952`) — **não** retrovalida as 9 000.

### Modo combinado `-da` — oráculo 5/5, não corpus

`da_n10.csv`: AntiDebug, ProcessEnum, Environments, MemoryScan, Overhead (`2042,56 < 3000`), todos exit 0, `timed_out=False`. TMW_ALL nas 9 000 é outra coisa (1 000 tentativas de corpus, sem esses estímulos).

---

## Item 3 — Timing e coerência temporal

**90/90 retidas.** `evidencias/matched_timing_n30.csv` + `matched_timing_summary_conventional.csv`.

| Braço | n | mediana ticks | min–max | abaixo do limiar 3000 |
|---|---|---|---|---|
| TMW0 (`-q`) | 30 | 2433,285 | 2168,12–2749,98 | 30/30 (100 %) |
| GO (`-go -q`) | 30 | 3083,210 | 2722,01–3845,31 | 11/30 (36,7 %) |
| GO_DO (`-go -do -q`) | 30 | 2104,770 | 2073,28–2146,11 | 30/30 (100 %) |

Não se repetiu até “passar”. Não se alterou `SkewMask.cpp` (invalidaria esta tabela).

**Esperas.** O briefing pede sequencial, sobreposto, aninhado, alertável, leituras repetidas, consistência de fontes, retrocesso, conversões, duplicação. Isso **não** está fechado nas 9 000. O oráculo de wait TickCount 4/10 e SleepEx alertable 0/10 é **JCVHT complementar** — não copiar para as tabelas Access. O PDF Access já admite timeout no braço com carga e no tratamento. Compensação do workload sintético ≠ deteção de Pin em malware.

---

## Item 4 — Recursos e comportamento (R4.3, concluído hoje)

**Regra de seleção a priori** (medianos `sample_condition_medians.csv`, persistente benigno, TMW0 `n_ok=0`, TMW_DO `n_ok≥6`, parede ~60 s):

| ID | SHA-256 | Campanha TMW0 | Campanha TMW_DO |
|---|---|---|---|
| BEN_28 | `0111d485…fa39` | n_ok=0, med_wall=1583 ms | n_ok=8/10, med_wall=60867 ms |
| BEN_46 | `0ab9f292…33a2` | n_ok=0, med_wall=1277 ms | n_ok=7/10, med_wall=60825 ms |
| BEN_47 | `0abd30c5…5dfd` | n_ok=0, med_wall=1380 ms | n_ok=8/10, med_wall=60847 ms |

Família no manifesto: `Windows_GUI_App`, perfil `persistent`, `included=true`. Fonte `Windows_Environment` 2026-10-14. **Não** é caso de malware.

**Protocolo R4.3.** Campanha `access_r43_skewmask_diag`. N=1 por braço. Janela 60 s. NAT / TMW0 (`-q`) / TMW_DO (`-do -q`). Restore `tomware_go` entre modos. `-mc` recusado (contadores mudam o custo). DLL conferida em cada RUN = `4BBC6270…F0E6`.

**Resultado (fonte: `run_meta.json`, não o `exit=0` do consola).**

| Amostra | Native | TMW0 | TMW_DO |
|---|---|---|---|
| BEN_28 | EXITED 1609 ms, exit **−1073741511**, peak_ws=0, n_tree=0 | EXITED 1687 ms, **mesmo exit**, peak≈70 164 480, n_tree=3 depois 0 | STILL_ALIVE 61016 ms, timed_out, exit **−1**, peak=68 624 384, n_tree=3 até ao fim |
| BEN_46 | EXITED 781 ms, **−1073741511**, peak_ws=0 | EXITED 1938 ms, **mesmo exit**, peak≈67 272 704 | STILL_ALIVE 61234 ms, timed_out, peak=68 521 984 |
| BEN_47 | EXITED 750 ms, **−1073741511**, peak_ws=0 | EXITED 1703 ms, **mesmo exit**, peak≈71 753 728 | STILL_ALIVE 61062 ms, timed_out, peak=69 128 192 |

`−1073741511` = `STATUS_ENTRYPOINT_NOT_FOUND` (`0xC0000139`). Native: o PE **não mapeia** (WS=0). TMW0: o Pin sobe (~64–72 MB) e cai no mesmo exit em <2 s. TMW_DO: a **árvore do Pin** permanece 60 s (`root_alive=1`, CPU raiz ~12,5–13,5 s). `stdout`/`stderr` vazios. `identified=false`. `not_a_claim`: alive_is_not_progress; not Arancino; not the 9000.

**Progresso observável?** Não determinado. Sem operação concluída, sem API, sem ficheiros novos, sem árvore nominativa. Classificação: **inconclusivo quanto a progresso**; a diferença de duração é **espera / estado do Pin sob `-do`**, não ganho de memória nem GUI a trabalhar.

**Cadeia malware evasivo (hash, anti-instr. observada, caminho, efeito da knob, comportamento extra):** **não existe** neste ensaio nem nas 9 000. `identify_summary.csv`: `identified=false`. `corpus.csv`: `targeted_evasion=unverified`. IAT ≠ ramo executado.

Permanência nas 9 000 (Wilson 95 %, persistentes, 250/célula): benigno TMW0 9,6 % → TMW_DO 52,8 %; maligno TMW0 32,8 % → TMW_DO 57,6 %. O PDF já trata isto como estado, não ganho. R4.3 mostra **um mecanismo compatível** (Pin vivo após falha de entrypoint nativa) — **não** reescreve as 9 000.

CTRL_PE / `TestRecoverWork` é **JCVHT**, rotulado, e não conta como caso Access.

---

## Item 5 — Baselines e comparação externa

**NAT / EMPTY / TMW0.** 1 000 cada nas 9 000 (`completeness.json`). Contrastar duração/recursos além dos desfechos: `outcomes_by_stratum.csv`, `sample_condition_medians.csv`. NAT benigno persistente `protocol_ok` 20/250; TMW0 24/250; TMW_DO 132/250.

**Pin sem Pintool.** Probe `pin.exe -- <alvo>` **inválida** neste motor. Condição PIN marcada `not_supported_by_engine`. EMPTY (`EmptyPinTool.dll` SHA-256 `804BE19B…B153C8`) é a baseline mínima **sob Pin**, não o custo exclusivo do motor. Documento: `evidencias/empty_tool_and_pin_probe.md`.

Custo total vs NAT ≠ efeito incremental vs TMW0. Manter os dois contrastes. Não apresentar EMPTY como Pin nu.

**Arancino.** Bloqueado. `evidencias/BLOQUEIO.md`. Ausente do repo. Público: necst/arancino, Pin **2.14** + VS2010, **só 32-bit**. Corpus Access: **100/100 x64**. Portar para Pin 3.28 **não é** o Arancino publicado. COBAI e Peekaboo ausentes. Sem ranking. Pedido **bloqueado**, não “atendido por limitação”.

---

## Item 6 — Manifesto, métricas, estatística, 22/30

**Manifesto.** `evidencias/corpus.csv`: 100 linhas, `included=true`, SHA-256, fonte, data, classe, família/tipo com método (`MalwareBazaar_Consensus` / `Microsoft`), packer/protector (muitos `unknown`/`none`), x64, perfil, `targeted_evasion=unverified`. Informações desconhecidas estão marcadas — não inventar VirusTotal.

**Filtros.** Janelas 120/60 e N=10 por célula são a priori. Filtro `sample_count > 0` para recursos é **post hoc** (não está em `experiment.config.json`). Methods deve dizê-lo. `n_pairs` efetivo ≠ 25 quando só 2 binários têm recursos (NAT benigno curto).

**Estatística.** Bootstrap 2 000, semente **705851366**, medianas convencionais, Wilson 95 % nas proporções. Sem p-valores. IC que contém zero ≠ equivalência.

**22/30.** Existe. `evidencias/fidelity_report.md`. 10 PE × NAT/EMPTY/TMW0/TMW_ALL × 3 = 120. Observador **externo** (exit + SHA de stdout). TMW0 vs TMW_ALL: 22 pares iguais, 8 diferentes. **Não** é fidelidade de syscalls/cobertura. Stdout vazio não demonstra comportamento. O PDF atual (bem) **não** usa 22/30 como prova. FidelityProbe não correu.

---

## Entregas obrigatórias do briefing

| # | Pedido | Onde neste pacote |
|---|---|---|
| 1 | Patch, testes, instruções | `scripts/Invoke-SingleRun.ps1` (v2.1); `scripts/Run-AccessR43.ps1`; `scripts/PASSO_A_PASSO_ACCESS_R43.txt`. **SkewMask.cpp não foi alterado.** |
| 2 | Manifesto e protocolo | `evidencias/corpus.csv`; `evidencias/completeness.json`; cabeçalho do R4.3 no script |
| 3 | Registos individuais | `r43_skewmask_diag/*/{run_meta.json,verdict.txt,resources.csv,stdout,stderr,process_tree.txt}`. As 9 000 JSON **não** vêm no zip (tamanho; originais no repo) |
| 4 | Indisponibilidade / exclusão | 6 517 unknown; Pin-sem-tool inválido; Arancino bloqueado; `process_tree.txt` R4.3 partido; `targeted_evasion=unverified` |
| 5 | Tabelas consolidadas | `evidencias/outcomes_by_stratum.csv`, `sample_condition_medians.csv`, `r43_skewmask_diag/summary.csv` |
| 6 | Commit / versões | HEAD `e382a6c`. DLL campanha `4BBC6270…F0E6`. Pin 3.28.98749. Coletor campanha ≠ v2.1. Scripts R4.3 **ainda untracked** neste HEAD |
| 7 | Relatório PT | este ficheiro + `03_R43_LEITURA.md` |
| 8 | Matriz dos seis revisores | `02_MATRIZ_SEIS_REVISORES.csv` |

Dados **preservados**: 9 000 JSON. **Reanalisados**: reclassificação 6 517, agregados. **Recoletados**: R4.3 (9 runs, id `access_r43_skewmask_diag`); Etapa 7 (1 800, id próprio, não neste zip).

---

## O que continua bloqueado (não marcar feito)

1. Bake-off Arancino / ranking COBAI / Peekaboo.
2. Refazer as 9 000 com coletor v2.1.
3. Traces de API / cobertura / equivalência.
4. “O malware usou as cinco checagens.”
5. Caso Access com cadeia checagem → ramo → knob → artefacto hashed no mesmo PE.
6. Alterar SkewMask ou repetir N=30.
7. Árvore pai/filho nominativa no R4.3 (`process_tree.txt`).
8. Misturar JCVHT 31/10 s com Access 100/9 000.
