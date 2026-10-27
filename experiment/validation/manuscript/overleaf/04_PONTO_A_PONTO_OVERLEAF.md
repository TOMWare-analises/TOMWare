# Ponto a ponto -- o que o artigo tem de dizer (Plano A v3)

Cada bloco: (a) o que o revisor pediu, (b) o que medimos, (c) o que colar no Overleaf, (d) o que nao escrever.
Software de toda a campanha: Pin **3.28.98749**, DLL SHA-256 a comecar por **4BBC6270**, snapshot `tomware_go`. Sem o commit `3040df7`.
TMW0 = Pin + TOMWare.dll, cinco knobs desligados (`-q`). Nao e Pin comum / bare Pin. EMPTY = Pin + EmptyPinTool.dll.

Regra unica de timing: N=30 no **corpo**; tabela antiga `-go` vs `-do` no **apendice**, rotulada como confundida. Nao apagar os numeros antigos.

---

## Editor (Eric Filiol) -- E.1

**(a)** Resultados exactos, sem overclaim, limitacoes explicitas; carta ponto a ponto.

**(b)** A carta EN deste zip e essa resposta. Quatro PE tentados como case study nao produziram marco.

**(c)** Uma subseccao de limitacoes (nao repetir o mesmo paragrafo em tres sitios). Manter as concessoes de M2 e M3.

**(d)** Nao afirmar que "continuar vivo sob Pin" e comportamento de malware preservado. A tabela 14x5 PASS e **oraculo**, nao prova de que esses PE usaram os cinco checks.

---

## Revisor -- Major 1.1 (timing pareado)

**(a)** Table 6 comparava `-go` com `-do`. Pedido: mesma carga, `-go` vs `-go -do`, mais Pin sem `-go`, todas as tentativas.

**(b)** TestOverhead.exe, N=30, nada descartado. TMW0 e Pin + TOMWare com knobs off, nao Pin comum.

| Braco | Knobs | N | Mediana ticks | Min-max | Abaixo de 3000 |
|---|---|---|---|---|---|
| TMW0 | `-q` | 30 | **2433.285** | 2168-2750 | 30/30 (100%) |
| GO | `-go -q` | 30 | **3083.210** | 2722-3845 | 11/30 (36.7%; Wilson 95% [21.9%, 54.5%]) |
| GO_DO | `-go -do -q` | 30 | **2104.770** | 2073-2146 | 30/30 (Wilson [88.6%, 100%]) |

Oraculo: anomalia se score **>** 3000 (OK se **<=**). Nenhum valor caiu em 3000.

**(c)** Colocar esta tabela no **corpo** como resultado principal (tab:timing_matched_n30). Mover a Table 6 antiga para **apendice** (app:timing_confounded), com os numeros originais e a nota "confundida". Abstract: taxa **11/30 vs 30/30**, nao "SkewMask eficaz" binario. Substituir qualquer frase de ~49% / 4080 vs 2081.

**(d)** Nao usar `matched_timing_summary.csv` (elemento inferior do par: 2417.74 / 3079.08). Nao apagar a tabela antiga -- move-la. Nao voltar a 9/31. Nao chamar TMW0 de ordinary Pin.

---

## Revisor -- Major 1.2 (esperas / relogio / retorno cedo)

**(a)** Testar seq, concorrente, leituras repetidas e wait que regressa cedo. Se nao houver timeline coerente, declarar limitacao.

**(b)** TestConcurrentWaitsLogged, N=5, sem `-go`, 20/20 exit 0. Medianas (ms):

| Braco | seq 2x200 | parede do Join | Tick+50 | WaitOne(500) |
|---|---|---|---|---|
| NAT | 406.218 | **213.678** | 62 | **45.867** |
| EMPTY (Pin + EmptyPinTool) | 433.421 | 571.867 | 62 | 445.610 |
| TMW0 (`-q`) | 441.209 | 553.862 | 78 | 441.411 |
| `-do -q` | 414.809 | 517.802 | 56 | 383.428 |

Os dois Sleep **ainda se intersectam** sob Pin (intersecao mediana ~207 / 212 / 196 ms; fracao 0.70-0.99). TickCount (um par) nao andou para tras. WaitOne ~46 ms so no nativo.

**(c)** Colar: *Nao garantimos relogio globalmente coerente sob Pin. A parede do Join fica maior que o sequencial sob Pin; isso nao significa que os Sleep tenham sido serializados. O SkewMask acumula um offset de processo e nao restaura o modelo parede-do-Join < seq.*

**(d)** Nao escrever: "o Pin inverte/serializa o overlap"; "o SkewMask preserva a geometria concorrente"; "EMPTY = Pin sem tool"; "WaitOne prova SleepEx".

---

## Revisor -- Major 1.3 (timeouts sem stdout)

**(a)** Diagnosticar corridas instrumentadas sem saida.

**(b)** O mesmo oraculo de espera com `-go` / `-go -do` da timeout -2 em 90 s. Causa: `SimulateOverhead` mete 10.000 `__nop` **antes de cada instrucao**. O TestOverhead completa sob `-go` e `-go -do` (tabela N=30).

**(c)** Uma frase: o -2 e timeout do gerador de carga, nao crash do SkewMask.

**(d)** Nao tratar -2 como falha da ferramenta nem como relogio a andar para tras.

---

## Revisor -- Major 2 (CPU / memoria / marcos / arvore)

**(a)** Explicar as quedas grandes de WS/CPU; marcos comparaveis; janela; arvore pai/filho.

**(b)** Duas janelas, protocolos diferentes:
- **Este artigo, Table 9:** 10 s, 31 PE. Os % publicados (parecer: WS 87% e 74%; CPU 38% e 29%) sao so deste protocolo.
- **Campanha 50+50 posterior (60 s):** SkewMask **estica** a parede. Benigno persistente TMW_DO-TMW0: **+55.452 ms** [30.685, 57.031]. Maligno persistente: **+37.387 ms** [26.146, 42.770] (n_pairs=23). WS benigno P -3.2 MB (IC inclui 0). Sem arvore nomeada; `child_count` sob Pin nao e processo-filho util.

**(c)** Rotular a Table 9 com **10 s / 31 PE**. Dizer que "ainda a correr" nao e "o mesmo trabalho". Citar +55 s / +37 s so como campanha **60 s / 50+50**.

**(d)** Nao republicar -87% / -38% como ganho. Nao importar os +55 s como se fossem a Table 9. Nao inventar arvore de processos.

**Estado honesto:** parcial (sem marcos comparaveis nem serie WS/CPU por PID neste pack).

---

## Revisor -- Major 3 (beneficio pratico) -- concessao

**(a)** Mostrar que os 14 malware usaram os checks; case studies com check identificado, ramo e comportamento extra.

**(b)** A tabela PASS e oraculo. Quatro candidatos (MAL_03, MAL_07, MAL_10, BEN_06), NAT / TMW0 / `-do`, 60 s: `new_files=0`, stdout vazio, check no PE nao localizado.

| Amostra | NAT | TMW0 (`-q`) | `-do -q` |
|---|---|---|---|
| MAL_03 | timeout 60 s | ACCESS_VIOLATION 0xC0000005 (~35 s) | timeout ~64 s |
| MAL_07 | exit 0 ~1.4 s | ACCESS_VIOLATION 0xC0000005 (~4 s) | timeout ~62 s |
| MAL_10 | timeout 60 s | timeout ~64 s | timeout ~64 s |
| BEN_06 | exit 3 ~1.0 s | exit 3 ~3.8 s | timeout ~62 s |

**(c)** Frase obrigatoria: *A recuperacao pratica de comportamento de malware suprimido **nao esta demonstrada**. A tabela dos 14 e so oraculo/compatibilidade. MAL_03/07/10 e BEN_06 nao sao case study.*

**(d)** Nao escrever que o malware usou os cinco checks. Nao tratar "ainda vivo aos 60 s" como unpack/drop/C2.

**Estado honesto:** nao atendido (pedido respondido por concessao).

---

## Revisor -- Major 4.1 (Module32)

**(a)** Controlo positivo: pass-through vs mascara, termino, entradas nao relacionadas.

**(b)** TestModule32 (Etapa 4): termino + `kernel32=1`, mas `pinish=0` ja sem `-dp` (nao prova filtro). Fixture 24/10: copia de `version.dll` como `%TEMP%\pinvm.dll` (**dummy, nao e Pin**).

- NAT: `fixture_pinvm=1`, count=32
- TMW0: `fixture_pinvm=1`, count=31
- `-dp` / `-da`: `fixture_pinvm=0`, count=30
- `kernel32=1` e `terminated=True` nos quatro

ProcessEnum (`processenum_base.csv`): pin.exe NAT=0 / TMW0=3 / `-dp`=0 / `-da`=0.

**(c)** Citar a fixture para hide/show do dummy. Citar TestProcessEnum para `pin.exe`.

**(d)** Nao escrever que o dummy e modulo real do Pin. Nao afirmar filtro de `pinvm` so com o TestModule32 antigo.

---

## Revisor -- Major 4.2 (familia memcmp)

**(a)** Pass-through vs mascara nas interfaces anunciadas.

**(b)** Exercitadas: `memcmp`, `_memicmp`, `RtlCompareMemory` -- NAT/TMW0 = PASS; `-dm`/`-da` = MASKED.
Nao exercitadas: `RtlEqualMemory`, `wmemcmp` (`EntryPointNotFound`).
`memcmp_passthrough=SAME_BAD` com n=7 de AAAAAAAA vs AAAAAAAB e igualdade por construcao -- nao e defeito.

**(c)** TestMemoryScan = controlo C++ de `memcmp`. Citar as tres APIs C#. Manter NOT_EXERCISED nas outras.

**(d)** Nao reivindicar as 12 rotinas. Nao citar SAME_BAD como falha da tool.

**Estado honesto (M4 no conjunto):** parcial.

---

## Revisor -- Major 4.3 (`-da`)

**(a)** Pequeno teste conjunto nos oraculos.

**(b)** 5/5 exit 0: AntiDebug zeros; ProcessEnum pin.exe=0; ambiente PIN_*=0; MemoryScan PIN_/pin.exe/pinvm/pinipc=0; TestOverhead 2040.7 < 3000.

**(c)** SUBSTITUIR a frase "-da nao foi avaliado". Uma frase + tabela tab:da_smoke. `-da` nao liga `-go`.

**(d)** Nao deixar a frase antiga no artigo so com uma nota de caption.

---

## Revisor -- Minor 1 (reproducao)

**(a)** Fixar commit/release; dizer a janela e a selecao do corpus.

**(b)** Pin 3.28.98749; DLL prefixo **4BBC6270**; snapshot `tomware_go`. O hash git `3040df7` esta desactualizado.

**(c)** Metodos: versao Pin + prefixo DLL + janela **10 s** neste artigo. Campanha 50+50 = 60/120 s, outra. Corpus submetido: 17+14 PE; `exclusions.csv`. Sem familias VirusTotal inventadas.

**(d)** Nao identificar a campanha por `3040df7`.

---

## Revisor -- Minor 2 (texto / Table 8)

**(a)** Encurtar limitacoes repetidas; wrap da coluna TestProcessEnum.

**(b)** Editorial. Sem experiencia nova.

**(c)** Uma subseccao de limitacoes. Ajustar o wrap da Table 8.

---

## Revisor -- Minor 3 (abstract)

**(a)** Rever a frase das "cinco contramedidas" depois do timing corrigido.

**(c)** *Cinco modulos seleccionaveis e oraculados em separado. TMW0 = Pin + TOMWare, knobs off. A pretensao quantitativa do SkewMask e 11/30 vs 30/30, nao a celula antiga `-go` vs `-do` nem as percentagens de WS a 10 s.*

---

## Depois de editar

Devolver o PDF do artigo. Conferimos contra esta lista. Envio ao jornal = artigo ja editado + carta EN (`01_...pdf`).
