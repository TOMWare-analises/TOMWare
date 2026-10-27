# Plano de execucao � IEEE Access-2026-38745

Escopo: so IEEE Access. Nada vai aos revisores antes da Etapa 11.
Nenhum commit sem autorizacao.

## Estado das etapas

| Etapa | Onde | Estado | Data |
|---|---|---|---|
| 0-6 | host/VM | **OK** | 22/10 |
| 7 Confirmacao 1800 | VM | **OK** | 23/10 |
| 8 Arancino | host | **OK** (bloqueio) | 23/10 |
| 9 Valores | host | **OK** | 23/10 |
| 10 Pacote Overleaf + cartas | host | **OK** | 23/10 |
| 11 Conferencia PDF artigo + envio | host | espera Overleaf | � |

## Etapa 7 � OK

1800/1800. Coletor 2.1.0. Exit inteiro em 1600 (88.9%). Nulo 200 (nao crash).
`exception_crash` 891 pela regra <0: 442 sao `0xC0000135` (tambem no NAT);
AV `0xC0000005` = 105 (5.8%). Nao reescreve os 9000.
Relatorio: `07_confirm/exitcode_report.md`.

## Etapa 8 � OK (bloqueio)

Sem bake-off. Arancino publico e Pin 2.14 + VS2010 + 32-bit; campanha e Pin 3.28 e 100 PE x64.
Kit 3.28 tem `ia32\bin`; isso nao desbloqueia o corpus x64 nem compara geracoes.
Relatorio: `08_arancino/BLOQUEIO.md`. Sem VM.

## Etapa 9 � OK

`09_values/MANUSCRIPT_VALUES.json` + `VALUES.md`. Corpus: so SHA-256 / fonte / x64 / perfil; familia e rotulo grosso.
Future work 32-bit + Arancino: `09_values/FUTURE_WORK.md` (nao corre agora).
Nao envia nada. PDF Overleaf continua o de 13/10.

## Etapa 10 � OK

PDFs: `ieee_access_revision/Access-2026-38745_Overleaf_Instructions.pdf`,
`..._Response_to_Reviewers.pdf` (EN), `..._Resposta_aos_Revisores.pdf` (PT).
Lista: `10_overleaf/PACOTE.md`. Nada a IEEE. Sem commit.

## Etapa 11 � espera o PDF novo do artigo

Quando o Overleaf exportar: conferir contra `09_values/MANUSCRIPT_VALUES.json`.
So depois autorizacao para commit e envio. 32-bit/Arancino depois do envio.
