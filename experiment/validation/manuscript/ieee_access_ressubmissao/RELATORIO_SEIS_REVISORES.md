# Relatório — Access-2026-38745 vs evidência no repositório

Data: 29/10/2026. DLL de campanha `4BBC6270`. Pin 3.28.98749. Snapshot `tomware_go`. Semente `705851366`.
PDF auditado: `Access-2026-38745_CURRENT.pdf` (SHA-256 `5CBC8E96…A98020`, 22 pp).

Os seis pareceres descrevem o manuscrito **antigo** (31 PE / 3 100 / 10 s, AntiDebug não pareado, 9/31, −87,2 %). O PDF atual **já não é esse texto**. Não refiz as 9 000 tentativas. Não misturei a campanha JCVHT.

## O que conferi nos CSV (não no texto)

| Facto | Ficheiro | Número |
|-------|----------|--------|
| 9 000 JSON, 9 000 triples, 0 duplicados | `experiment/results/campaign/corpus_aligned_10k/completeness.json` | 9 condições × 1 000 |
| `crash_exit` bruto | o mesmo | 6 517, todos com `exit_code` nulo |
| Crash verdadeiro com código | auditoria | **0** |
| Reclassificação | `notes/campaign_audit_report.md` | `exited_before_limit_exit_code_unknown` |
| Table 19 TMW0 curtas | `outcomes_by_stratum.csv` somado | 406 sem código + 88 timeout + 6 launch = 500 |
| Table 19 TMW0 persistentes | idem | 371 + 106 janela + 23 launch = 500 |
| AntiDebug 3/3 vs 3/3 | `oracles/guest/antidebug_n3.csv` | `-gdb -q` positivo; `-gdb -dd -q` OK |
| Timing N=30 | `matched_timing_summary_conventional.csv` | TMW0 30/30; GO 11/30 (36,7 %); GO_DO 30/30 |
| `-da` oráculos | `da_n10.csv` | 5/5 exit 0 (Overhead 2042,56 < 3000) |
| ProcessEnum oráculo | `processenum_base.csv` | NAT 0 pin.exe; TMW0 3; `-dp` 0; `-da` 0 |
| Corpus 100 | `experiment/corpus/corpus.csv` | 50+50, x64, `included=true` |
| Arancino | `oracles/arancino/BLOQUEIO.md` | ausente; Pin 2.14; só 32-bit |
| 22/30 exit+stdout | `notes/fidelity_report.md` | observador externo; **não** API/cobertura |

O PDF atual já usa 100 PE, 9 000, AntiDebug pareado, 11/30→30/30, Table 19 com “sem código”, e recusa equivalência comportamental. Isso responde a maior parte dos seis pareceres **com dados que já estavam no tree**.

## Coletor (pedido 1 do briefing)

Causa dos 6 517: `Invoke-SingleRun.ps1` lia `$proc.ExitCode` após redirect; em PowerShell 5.1 o nulo comparado com `< 0` virava `exception_crash` / `0x`. Os JSON originais **não foram alterados**.

Correção no código (campanhas novas): `Get-SafeProcessExitCode` em `experiment/scripts/runner/Invoke-SingleRun.ps1` (v2.1) — `Refresh`, `HasExited`, segundo `WaitForExit()` sem timeout. Confirmado à parte na Etapa 7 (1 800 runs, 88,9 % com exit inteiro; AV verdadeiro 105/1 800, não 72 %).

Não transformar os 6 517 em sucesso nem em crash. O PDF já diz: não se calcula taxa de sucesso a partir deles.

## Validação funcional (pedido 2)

Atendida nos oráculos da campanha `4BBC6270`, com o alcance seguinte:

- AntiDebug: só PEB `BeingDebugged` / `NtGlobalFlag` e o estímulo `-gdb`. Não é depurador anexado.
- ProcessEnum: `TestProcessEnum` Toolhelp imagem `pin.exe`. Variantes ANSI/Unicode/Module32 existem em CSVs auxiliares (`module32_fixture.csv`); não substituem `NtQuerySystemInformation`.
- SanitizePinEnvVars / InstMemcmpMask / `-da`: `da_n10.csv` e `memcmp_n10.csv`. No DLL de campanha, `_memicmp_l` de 3 argumentos ainda ACCESS_FAULT; o arranjo de 4 argumentos é a DLL `D55EC952`, **outra** identidade — não retrovalidar os 9 000.
- TMW_ALL no corpus não substitui a bateria de oráculos; as duas existem e devem permanecer separadas.

## Timing (pedido 3)

As 90 linhas de `matched_timing_n30.csv` estão retidas. Não repetir até “passar”. Esperas concorrentes sob Pin: timeout no braço com carga e no tratamento (limitação no PDF). TickCount 4/10 e SleepEx alertable 0/10 são da campanha **JCVHT** complementar; não os copie para as tabelas Access 9 000.

## Recursos e comportamento (pedido 4)

O PDF Access **já não traz −87,2 / −38,5**. Sob a janela de 60 s, TMW_DO aumenta a fração que permanece observável (benignos persistentes TMW0 24/250 → TMW_DO 132/250). Isso é mudança de estado / espera, não ganho. Não há, nos 9 000, traces de API nem bytes escritos por binário persistente. O demonstrador `TestRecoverWork` (CTRL_PE) é **JCVHT**, rotulado, e não conta como caso Access.

## Baselines e Arancino (pedido 5)

NAT / EMPTY / TMW0 / cinco knobs / TMW_ALL: 1 000 cada. Probe Pin-sem-tool inválida — EMPTY não isola o motor. Arancino: **bloqueado** (`BLOQUEIO.md`). COBAI e Peekaboo ausentes. Não fabricar ranking.

## Manifesto e estatística (pedido 6)

`corpus.csv` é o manifesto. Evasão nos 50 malware = `unverified`. Bootstrap 2 000 e semente 705851366 estão no `manuscript_values.json` e no PDF. Filtro `sample_count > 0` **não** estava em `experiment.config.json` — continua retrospectivo; o Methods deve dizê-lo. 22/30 existe e está documentado; **não** é fidelidade comportamental; o PDF atual (bem) não o usa como prova.

## O que **não** vou marcar como feito

| Pedido | Porquê |
|--------|--------|
| Bake-off Arancino | ISA, geração Pin, OS e corpus diferentes |
| Refazer 9 000 com coletor v2.1 | Nova campanha; os JSON antigos ficam |
| Traces API / cobertura | Etapa 6 foi observador externo |
| “O malware usou as cinco checagens” | `identified=false` / `unverified` |
| Alterar `SkewMask.cpp` ou repetir N=30 | Invalidaria a tabela de timing já no PDF |
| Misturar JCVHT 31/10 s com Access 100/9 000 | Protocolos distintos |

## R4.3 (29/10/2026) — diagnóstico de persistência

Três benignos persistentes (BEN_28/46/47), NAT / TMW0 / TMW_DO, 60 s, DLL `4BBC6270`, id `access_r43_skewmask_diag`. Native e TMW0: `EXITED_BEFORE_WINDOW`, exit `−1073741511` (`STATUS_ENTRYPOINT_NOT_FOUND`). TMW_DO: `STILL_ALIVE_AT_WINDOW` ~61 s (árvore do Pin, `n_tree=3`). `identified=false`. Leitura: espera/estado, não progresso, não reescrita das 9 000. Detalhe: `03_R43_LEITURA.md`.

## Carta

Inglesa já versionada: `experiment/validation/manuscript/Access-2026-38745_Response_to_Reviewers.pdf`. Usar a matriz CSV desta pasta para conferir cada item antes de reenviar. Não commitar `.env` nem amostras. Pacote do colaborador: pasta/zip `Access-2026-38745_ANALISE_AMIGO_2026-10-29` em Downloads. **Não** enviar esse zip à IEEE.
