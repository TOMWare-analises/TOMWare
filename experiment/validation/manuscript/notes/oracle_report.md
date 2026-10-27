# Etapa 4 � relatorio dos oraculos (VM, 22/10/2026)

Fonte: `Downloads\etapa4_oracles` copiada para `04_oracles/from_vm/`.
Timeout declarado: 90 s (probe Pin: 30 s). Coletor v2.1: `exit_code` preenchido (0 nos runs que terminaram).
Timing N=30: **nao repetido**. Proveniencia no CSV `timing_n30_provenance.csv`.

## AntiDebug N=3 (pareado)

| Braco | knobs | 3/3 | Indicadores PEB / IsDebuggerPresent |
|---|---|---|---|
| AD_NAT | nativo | OK, exit 0 | todos 0 |
| AD_TMW0 | `-q` | OK, exit 0 | todos 0 (Pin sozinho nao arma o PEB) |
| AD_GDB | `-gdb -q` | 3/3 alerta | BeingDebugged=1, NtGlobalFlag=1, IsDebuggerPresent=1 |
| AD_GDB_DD | `-gdb -dd -q` | 3/3 OK | todos 0 |

CheckRemoteDebuggerPresent, ProcessDebugPort e ProcessDebugObjectHandle ficaram 0 em todos os bracos (fora do `-gdb` e do modulo).

Isto fecha o 3+3 do manuscrito: baseline `-gdb -q` positivo; tratamento `-gdb -dd -q` suprime. NAT e TMW0 sem `-gdb` sao controlos negativos.

## `-da` nos 5 oraculos

Todos exit 0, sem timeout.

| Oraculo | knobs | Resultado |
|---|---|---|
| TestAntiDebug | `-gdb -da -q` | PEB/IsDebuggerPresent = 0, OK |
| TestProcessEnum | `-da -q` | pin.exe / pinvm / pinipc / TOMWare = 0, OK |
| TestGetEnvironments | `-da -q` | PIN_* = 0, OK |
| TestMemoryScan | `-da -q` | PIN_ / pin.exe / pinvm / pinipc = 0 |
| TestOverhead | `-da -q` | 2040,7 < 3000, OK |

## Probe Pin sem `-t`

`pin.exe -- TestAntiDebug.exe` terminou com **exit 0**, stdout do oraculo, stderr vazio.
Nesta corrida isolada o Pin sem pintool **funcionou**. O `campaign.json` da campanha 9000 tem `pin_condition_valid=false` (probe antigo, possivelmente com outro Pin a correr ou IPC). Nao afirmar que Pin sem `-t` e sempre invalido. Afirmar: a campanha omitiu a condicao PIN porque o probe daquele dia falhou; um probe isolado em 22/10 completou.

## Module32 e waits (controlo positivo)

Timeout 90 s declarado.

| Run | Resultado |
|---|---|
| M32 NAT / EMPTY / TMW0 / `-dp` | exit 0, PASS_MASK_OR_CLEAN, pinish=0 |
| WAIT NAT | WAIT_MODEL_OK, alertable 46 ms |
| WAIT EMPTY / TMW0 | WAIT_MODEL_CHECK (alertable ~400 ms): Pin atrasa waits; o processo termina |
| WAIT `-go` e `-go -do` | timeout 90 s, exit -2 (codigo do runner). Igual a corrida anterior |

Module32 com pinish=0 mesmo sem `-dp` nao prova esconder `pinvm.dll`; o oraculo certo para `pin.exe` continua a ser o TestProcessEnum.

## Fumaca `-mc` � DLL do snapshot tem contadores

`module_events_smoke.json` gravado (999 bytes). Com `-dp`:
`calls_intercepted=140`, `processes_examined=142`, `processes_filtered=3`.
Outros modulos a 0 (so `-dp` estava ligado). **Etapa 5 pode usar `-mc` sem recompilar.**

## Timing N=30 (reutilizado)

90 runs, hash `76208218�`. Medianas convencionais: TMW0 2433,285; GO 3083,210 (11/30 abaixo); GO_DO 2104,770 (30/30).
