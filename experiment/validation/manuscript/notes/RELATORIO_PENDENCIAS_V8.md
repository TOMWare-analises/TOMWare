# Relatorio curto - pendencias v8 (2026-10-27)

Identidade. Pin 3.28.98749. Snapshot `tomware_go`.
TOMWare.dll SHA-256 `4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6`.
Git HEAD `3040df722967fb0e699be6f279837a0611c4ad38` (25/09/2026) NAO gera esta DLL. Sem tag. Nao recompilamos so para criar tag.

Fonte dos numeros: `C:\Users\marge\Downloads\jcvht_t2_n10_v7b` (campanha `t2_n10_v7b`), identify em `jcvht_identify`, coletor em `jcvht_coletor_fumo_v7`. Sem campanha N=10/N=30 nova.

## 1. SkewMask

### TickCount em DO03, DO05, DO07, DO09

Causa provavel (consistente com todos os dados). `Hook_GTC` devolve `pGTC() - (DWORD)msOff`, com `msOff` truncado a ms inteiro. `CalibratedSleep` aumenta `g_qpcSkewTicks` quando os sleeps paralelos terminam. O GetTickCount real so avanca a cada ~15.6 ms; se o skew cruza uma fronteira de ms inteiro entre duas leituras sem o GTC real ter avancado, o valor aparente recua 1 ms. O QPC usa subtracao 64-bit fina e avanca ~0.78 ms entre leituras, por isso `qpc_regress=0` no mesmo intervalo.

Evidencia (`experiment/results/oracles/waits_clock_n10.csv`):
- `clock_during_overlap`: `tick_regress=1` so em DO 03/05/07/09; 0 nas outras 36 corridas.
- `tick_first < tick_last` nessas quatro (ex. DO03 779187 -> 779391). Nao e wrap de 32 bit.
- `clock_burst1000` (sem sleep concorrente): `tick_regress=0` em 40/40.
- NAT / EMPTY / TMW0: zero regressoes (sem hook de GTC).

Correcao. Nenhuma em `Hook_GTC`. Um clamp monotonico mudaria a semantica da Table 6. DLL antiga intacta.

### SleepEx alertavel, 10/10 timeout 180 s

Localizacao, nao causa confirmada. O hang e especifico de `SleepEx(500, alertable=true)` sob `-do`. O `SleepEx(200, alertable=false)` da mesma corrida RETORNA (`sleepex_nonalert` ~200-270 ms) e os `Thread.Sleep` paralelos tambem retornam. O teste imprime `openthread_ok=True` e `queueuserapc_rv=1` e depois bloqueia em `sleeper.Join()`: o thread em SleepEx alertavel sob `CalibratedSleep` nao acorda com o APC.

Evidencia. DO 10/10: 12 eventos, ultimo `sleepex_nonalert`, sem `sleepex_alert`. NAT/EMPTY/TMW0 30/30: `rv=192`, `apc_callback=1`, ~45-230 ms. Sem falta em stderr (nao e crash). Collector mata a 180 s -> `exit=-2`. Nao e falha de OpenThread nem de QueueUserAPC.

O que NAO se confirmou. Testei a hipotese de reentrada no `PatchApi` (ultimo trampolim a sobrescrever `pSleepEx`) e REVERTI: o ponteiro devolvido por `RTN_Replace` chama o original, nao o hook, por isso a hipotese nao se sustenta. `SkewMask.cpp` ficou igual a fonte da DLL 4BBC6270. A questao em aberto e se o wrapper `CalibratedSleep` quebra a entrega alertavel do APC. Confirmar exige build instrumentada + so o teste DO/SleepEx. Sem alterar SkewMask e sem recompilar enquanto a causa nao for provada. O hang de N=10 continua a ser o resultado registado.

## 2. InstMemcmpMask

Causa do exit 2 (evidenciada pelo stderr). `_memicmp_l` tem 4 argumentos. O hook usava `wMemcmpI` com `argc=3`. `memicmp_l_PIN` passa pelo ramo MASKED (nao chama o original) e imprime `MASKED ret=1`. O controlo seguinte (`memicmp_l_same`) encaminha para o original com prototipo errado: o 4.o argumento (locale) fica com lixo `0xffffffffffffffff` -> `RECEIVED_ACCESS_FAULT`. Apos 64 faltas no mesmo IP, `Instrumentation.cpp` faz `exit(2)`.

Evidencia.
- MC3_NAT / MC3_TMW0: exit 0; `memicmp_l_PIN=PASS`; `memicmp_l_same=OK`; `memicmp_l_passthrough=DIFF_OK ret=-1`.
- MC3_DM / MC3_DA: `memcmp` / `_memicmp` / `RtlCompareMemory` MASKED + same/passthrough OK; `memicmp_l_PIN=MASKED`; sem `memicmp_l_same`; stderr ACCESS_FAULT em `0xffffffffffffffff`; `timed_out=false`; exit 2.
- Exportos ABSENT (`RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `bcmp`) permanecem `NOT_EXERCISED`. `_memicmp_l_export=FOUND`.

Correcao no source: wrapper `wMemcmpIL` a 4 args + `RTN_ReplaceSignature` com `argc==4`. NAO validado: nao ha build nova nesta maquina.

## 3. Beneficio pratico

Nao resolvido. 31/31 `identified=false`. Imports/strings sao pistas (MAL_08 Toolhelp, MAL_12 FindWindow, MAL_14 NtQuerySystemInformation). Sem ramo executado, sem triade NAT / TMW0 / knob, sem artefacto extra com hash. Permanecer activo nao conta.

## 4. Recursos / Table 9

Limitacao declarada. O coletor de 10 s (`experiment/results/oracles/collector/`) e fumo sintetico (powershell + PING + ficheiro). Table 9 e 17+14 PE / 10 s. Nao ha o mesmo executavel benigno e malicioso com marcos + CPU + WS + pico + arvore sob NAT / TMW0 / knob. Nao da para dizer se as diferencas da Table 9 sao trabalho comparavel ou progresso alterado.

## 5. Entrega

- `experiment/validation/manuscript/notes/evidence_matrix.csv` actualizado.
- `experiment/results/oracles/omitted_files.csv` + `freeze_manifest.py` aponta a `results/oracles` e ja nao apaga o catalogo dos 9000 JSON.
- Codigo: commit `3040df7`, sem tag. DLL: SHA-256 acima.
- Unica alteracao de source mantida: `InstMemcmpMask.cpp` (`_memicmp_l` como 4 args). `SkewMask.cpp` NAO foi alterado.
- Pendencias que NAO se marcam resolvidas: T1 (beneficio), Table 9 (recursos), causa confirmada do hang do SleepEx alertavel, e validacao do fix de `_memicmp_l` numa DLL nova.
