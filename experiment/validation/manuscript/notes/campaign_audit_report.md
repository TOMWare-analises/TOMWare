# Auditoria da campanha corpus_aligned_10k (Etapa 2)

Os 9.000 JSON brutos **nao foram alterados**. Esta pasta so contem reclassificacao e agregados.

## Desfechos

- JSON: 9000 / esperados 9000; triples unicos: 9000.
- `raw crash=true`: 6517; desses, `exit_code` nulo: 6517.
- Reclassificados para `exited_before_limit_exit_code_unknown`: 6517.
- `exception_crash` verdadeiro (codigo de saida conhecido): 0.
- Motivo: `Invoke-SingleRun.ps1` le `$proc.ExitCode` depois do redirecionamento; nulo comparado com `< 0` vira crash e `exception_code` `0x`.
- **Nao escrever** no artigo que a maioria das amostras curtas crashou.

Sobrevivencia persistente (window_controlled_termination / 250, Wilson 95%):

- Benigno: NAT 8.0% [5.2, 12.0]; EMPTY 11.2%; TMW0 9.6%; TMW_DO 52.8% [46.6, 58.9]; TMW_ALL 56.4% [50.2, 62.4].
- Maligno: NAT 54.4% [48.2, 60.5]; EMPTY 32.4%; TMW0 32.8%; TMW_DO 57.6%; TMW_ALL 64.0% [57.9, 69.7].

NAT benigno curto: 20 runs com recursos em so 2 de 25 binarios. Contraste EMPTY-NAT de WS/CPU nesse estrato tem n_pairs=2.

## Reclassificacao usada

| audited_outcome | criterio |
|---|---|
| launch_failed | launch_success = false |
| timeout_expired | timeout = true |
| window_controlled_termination | persistent chegou ao fim da janela |
| exited_before_limit_exit_code_unknown | crash=true e exit_code nulo e exception_code `0x` |
| exception_crash | crash=true com codigo de saida conhecido |
| natural_exit | natural_completion sem o artefato acima |

## Recursos

- Filtro `sample_count > 0` e **post hoc**. Nao consta em `experiment.config.json`.
- Tempo de parede persistente descreve duracao observada, nao desempenho.
- `n_pairs_*` nas tabelas de contraste e o n efetivo. Nao usar `n_binaries = 25` quando so 2 pares tem recursos.

## Contraste que NAO inclui zero (nao generalizar como nulo)

- TMW_DM - TMW0, malignos curtos, WS: 0.451 MB IC95% [0.049, 0.805] (n_pairs_ws=25; exclui zero=true).

## Frases proibidas nesta revisao

- 31 binarios / 3100 lancamentos / 10 s / 155/155 / -87% / -38% / 9/31.
- frase: short-lived runs are mostly crash-exit.
- frase: sample_count > 0 estava fixado a priori no experiment.config.json.

Medianas: convencionais (media dos dois centrais se n par). Bootstrap 2000, seed 705851366. Wilson 95% nas proporcoes.
