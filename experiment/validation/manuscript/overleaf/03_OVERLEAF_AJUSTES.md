# Ajustes Overleaf JCVHT (v3; 26/10/2026)

Uma unica regra de timing: N=30 no corpo; tabela antiga no apendice.
Nao apagar numeros. Substituir as frases de 49% e de "-da nao avaliado".
TMW0 = Pin + TOMWare, knobs off -- nao "ordinary Pin".
Graficos opcionais, anexados a parte. Plano B extra ate 02/11.

## Table 6 (timing pareado) -- corpo

| Arm | Knobs | N | Mediana ticks | Min-max | Abaixo de 3000 |
|---|---|---|---|---|---|
| TMW0 | `-q` | 30 | 2433.285 | 2168-2750 | 30/30 |
| GO | `-go -q` | 30 | 3083.210 | 2722-3845 | 11/30 (36.7%) |
| GO_DO | `-go -do -q` | 30 | 2104.770 | 2073-2146 | 30/30 |

Oraculo: anomalia se score **>** 3000 (OK se **<=**). Nenhum valor = 3000.
Nao usar `matched_timing_summary.csv`.
Celula antiga `-go` vs `-do` (ex. 4080 vs 2081 / ~49%): **so no apendice**, rotulada como confundida.

## Abstract

Cinco modulos **selecionaveis e oraculados em separado**.
TMW0 = Pin com TOMWare carregado e knobs desligados (`-q`), nao Pin comum.
Pretensao quantitativa do SkewMask: **11/30 vs 30/30**, nao a celula antiga e nao as % de WS a 10 s.

## Frases a SUBSTITUIR (nao basta a nota da caption)

1. Qualquer conclusao funcional da diferenca ~49% / 4080 vs 2081:
   a celula antiga e confundida; o resultado desta revisao e a Tabela N=30.
2. Qualquer frase "-da nao foi avaliado":
   `-da` foi smoke-testado nos cinco detectores (tab:da_smoke); nao e campanha 3.100.

## Table 9

Rotular janela **10 s / 31 PE**. Usar os % que ja estao no artigo (parecer: WS 87% e 74%; CPU 38% e 29%). **Nao** como ganho. Citar +55.452 ms / +37.387 ms so como campanha **60 s / 50+50**, outra.

## Waits (5.5)

Nao garantimos relogio globalmente coerente sob Pin. N=5 QPC (24/10):
nativo `par_wall` 213.678 < seq 406.218; EMPTY/TMW0/`-do` tem `par_wall` 571.867 / 553.862 / 517.802 (Join mais longo que o seq).
Os dois `Sleep` **ainda se intersectam** sob Pin (intersecao mediana ~207 / 212 / 196 ms; fraccao 0.70-0.99). Nao escrever que o Pin serializa as esperas.
O que falha e o modelo `par_wall < seq`, por overhead de criacao/Join/JIT, nao a geometria dos dois Sleep.
Alertavel ~46 ms **so** nativo (`WaitOne`, nao `SleepEx`). TickCount (um par) nao andou para tras; isso nao prova monotonicidade geral.
SkewMask = offset de processo (`AccumulateSkewTicks`). Nao escrever que restaura geometria concorrente nem que o `double_count_risk` prova contagem dupla do offset.
EMPTY = Pin + `EmptyPinTool.dll`, nao Pin sem tool.

## Module32 (Table 8 / functional)

Fixture 24/10: dummy `pinvm.dll` (copia de `version.dll`) visivel NAT/TMW0, oculto `-dp`/`-da`; `kernel32` mantido. Nao escrever que o dummy e modulo real do Pin. ProcessEnum: pin.exe 0 / 3 / 0 / 0.

## memcmp family

Oraculados: `memcmp`, `_memicmp`, `RtlCompareMemory` (PASS vs MASKED). `wmemcmp` e `RtlEqualMemory` sem export no guest. Nao citar `SAME_BAD` (n=7 iguais por construcao).

## Major 3

Beneficio pratico **nao demonstrado**. MAL_03/07/10 e BEN_06 **nao** sao case study. Tabela dos 14 = oraculo/compatibilidade.

## Table 8

Wrap da coluna TestProcessEnum. Uma subseccao de limitacoes.

## Metodos

Pin **3.28.98749**. DLL SHA-256 prefixo **4BBC6270**. Snapshot `tomware_go`. Sem `3040df7`.
TMW0 = Pin + TOMWare, knobs off.
