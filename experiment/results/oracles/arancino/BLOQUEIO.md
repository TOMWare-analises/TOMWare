# Etapa 8 � bloqueio documentado (Arancino)

Data: 2026-10-23. Host only. Sem clone, sem build, sem bake-off na VM.
Decisao: **bloqueio**. Nao ha comparacao experimental justa no protocolo Pin 3.28 / 100 PE x64.

## Decisao

Nao se corre Arancino contra TOMWare.M nesta revisao.
O manuscrito ja diz isso (Table 1; Sec. V-C). Esta etapa so **fecha a evidencia** do porqu�.
Nao se reivindica superioridade em cobertura, compatibilidade ou custo.

## O que existe (factos)

| Item | Evidencia |
|---|---|
| Arancino no repo TOMWare | **Ausente.** Glob `*Arancino*` = 0. Tambem 0 para COBAI e Peekaboo. |
| Fonte publica | [necst/arancino](https://github.com/necst/arancino), HEAD `7de9dd89` (2017-06-06). `pushed_at` GitHub 2022-04-28; ultimo commit de codigo 2017. |
| Pin exigido pelo README do Arancino | **Pin 2.14-71313-msvc10-windows** (`src/README.md`). VS **2010 obrigatorio**. |
| Arquitetura do Arancino | Artigo DIMVA 2017 [4]: *�Arancino currently supports only 32-bit binaries�*; 64-bit fica como trabalho futuro (WoW64 / far jmp). Release usa `ScyllaDLLx86.dll`. |
| Pin desta campanha | **3.28.98749** (`pin/README`; `01_freeze/freeze_meta.json`). Kit **tem** `ia32\bin\pin.exe` e `intel64\bin\pin.exe`. |
| Corpus `corpus_aligned_10k` | **100/100 x64.** Zero linhas `,x86,` em `corpus.csv`. |

`pin.exe -version` no host nao foi usado: Pin no host trava IPC (regra do laboratorio: Pin so na VM). A versao fica no README e no manifesto congelado.

## Por que bake-off nao e valido aqui

Qualquer �Arancino vs TOMWare.M� neste setup mistura pelo menos quatro factores:

1. **Geracao do Pin** � 2.14 (2015, CRT/VS2010) vs 3.28 (API, PinCRT, layout). Portar o codigo 2017 para 3.28 **nao e o Arancino publicado**; e outra ferramenta.
2. **ISA do alvo** � Arancino e 32-bit. Os 100 PE da campanha sao x64. `ia32\bin\pin.exe` do kit 3.28 nao instrumenta este corpus.
3. **Protocolo** � 9 bracos NAT/EMPTY/TMW0/modulos/`-da`, 60 s, coletor 2.1, semente 705851366. Arancino e um unpacker integrado (`-antiev` / PINdemonium), nao knobs independentes no mesmo ladder.
4. **Ambiente** � paper: VirtualBox + Windows 7, 7006 amostras VT 2016�2017. Aqui: VMware Windows 10, 100 PE 2026. OS e corpus sao confounders.

Caminhos rejeitados (nao executar):

- Compilar `PinUnpacker.sln` com VS2010 + Pin 2.14 numa VM extra: outro Pin, outro OS, outro corpus ? nao compara.
- Compilar o fonte 2017 contra Pin 3.28 ia32: unofficial; API Pin 2.x; ainda 32-bit; corpus x64 fora.
- Reescrever Arancino para x64/Pin 3.28: implementacao nova, fora do prazo da revisao, e deixaria de ser o [4].

## O que o artigo pode (e nao pode) dizer

Pode (ja esta no texto de 13/10; manter na Etapa 9):

- Table 1: Arancino e o Pintool defensivo mais proximo; beneficio comparativo **nao testado**.
- Sec. V-C: *�No direct experimental comparison was conducted with Arancino [4].�*
- Cartas R1.3 / R2.5: so tabela arquitetural; sem ranking experimental.

Nao pode:

- �TOMWare.M supera o Arancino.�
- Qualquer numero de cobertura / crash / memoria / tempo versus Arancino, COBAI ou Peekaboo.
- Apresentar o kit `ia32` do Pin 3.28 como se tornasse o bake-off viavel.

Future work (Etapa 9, pedido 23/10): (a) TOMWare Win32 + Pin 3.28 ia32, oraculos e corpus 32-bit opcional; (b) bake-off Arancino num protocolo 32-bit partilhado. Texto para o �VIII: `09_values/FUTURE_WORK.md`. Nao e debito desta revisao.

## Relacao com COBAI / Peekaboo

Ausentes do repo. Sao arquitecturas diferentes (DBI dedicada; extracao de comportamento), nao Pintools no Pin 3.28. Continua so Table 1.

## Snapshot / VM

Nao precisa. Nada a instalar no guest. Restaurar `tomware_go` so se a proxima etapa suja a VM (Etapa 9 e host).
