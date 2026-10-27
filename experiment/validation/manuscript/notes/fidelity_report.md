# Etapa 6 � relatorio de fidelidade (Q7)

Fonte: `Downloads\etapa6_fidelity` -> `06_fidelity/from_vm/`.
DLL do snapshot: hash comeca por `4BBC6270` (campanha 9000). Sem FidelityProbe.
Observador: `external_ps` (exit, duracao, SHA-256 stdout/stderr, processos filhos, ficheiros novos em TEMP/Public/Desktop/Downloads).
10 PE x NAT / EMPTY / TMW0 / TMW_ALL x 3 = **120/120**. Timeout 45 s.

## Cobertura

Todos os bracos: 30 runs. Amostras: BEN_05/06/10/12/14, MAL_01/02/06/07/11.
Timeouts (`-2`): 5 (BEN_06 TMW_ALL 3/3; BEN_12 TMW_ALL 2/3).
AV `0xC0000005`: 4 (MAL_07 EMPTY 2, TMW_ALL 2).
Ficheiros novos: 11/120. Filhos observados: 100/120 (muitos sao o proprio alvo).

## TMW0 vs TMW_ALL (efeito dos 5 modulos)

30 pares (amostra, tentativa). Exit+stdout iguais: **22**. Diferentes: **8**.

| Amostra | TMW0 | TMW_ALL | Leitura |
|---|---|---|---|
| BEN_05 | exit 1, stdout 0 | exit 1, stdout 0 (~40 s) | Mesmo desfecho; mais lento |
| BEN_10 | exit 0, 6941 B | exit 0, 6941 B (mesmo SHA) | stdout identico |
| BEN_14 | exit 11, 28 B | exit 11, 28 B (mesmo SHA) | stdout identico |
| BEN_12 | exit 0, 754 B | 754 B; 2/3 timeout | Texto igual; processo nao sai a tempo |
| BEN_06 | exit 3 | timeout 3/3 | `-da` altera o desfecho |
| MAL_01/02/11 | exit 2, stdout 0/255 | igual a TMW0 | Pin ja mudou vs NAT; `-da` nao muda mais |
| MAL_06 | 2x exit 2, 1x 0 | exit 2 | Quase igual |
| MAL_07 | exit 0 | 2x AV, 1x 0 | `-da` piora o termino |

EMPTY vs TMW0: 27/30 iguais (carregar TOMWare off ~= EmptyPin).
NAT vs TMW0: 21/30 iguais. Os MAL passam muitas vezes de NAT exit 0 para Pin exit 2.

## O que se pode escrever

Observacao externa de saida, codigo de saida, filhos e ficheiros, em escada NAT/EMPTY/TMW0/`-da`.
Em 3/5 BEN (05, 10, 14) o stdout e o exit de TMW_ALL coincidem com TMW0.
`-da` alonga a parede do relogio (custo, nao "ganho").

## O que nao se pode escrever

Equivalencia comportamental, traces de API, cobertura BBL, "as contramedidas preservam a fidelidade".
FidelityProbe nao correu (nao pode coexistir com TOMWare). Sem ProcMon/ETW de kernel.
Nao misturar com 155/155 nem com JCVHT.
