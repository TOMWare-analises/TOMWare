# Regras de validade das métricas (fixadas a priori)

Definidas **antes** de qualquer execução e aplicadas mecanicamente pelos validadores.
Nenhuma regra depende do sinal ou da magnitude de um resultado. Falhas, timeouts e dados
ausentes **permanecem** no conjunto de auditoria e são reportados à parte. Nunca são
apagados nem substituídos por zero.

## 1. Perfil da amostra

O perfil é atributo da amostra no `corpus.csv`, definido antes da campanha e nunca
reclassificado depois de ver resultados.

- `short_lived`: aguarda conclusão natural até `observation.short_lived.timeout_seconds`.
- `persistent`: janela fixa `observation.persistent.window_seconds`, com encerramento controlado no fim.

## 2. Curta duração (`short_lived`)

**Tempo de parede** é válido para um contraste A−B somente se, nos dois lados:
1. `launch_success = true`;
2. timestamps válidos (`end >= start`, duração monotônica > 0);
3. `natural_completion = true`;
4. `timeout = false`;
5. `collector_failure = false`.

**CPU e memória** são válidas somente se, nos dois lados:
1. houver pelo menos `min_resource_samples` amostras (padrão: 3);
2. o intervalo efetivo de amostragem estiver dentro de `sampling.allowed_range_ms`;
3. a coleta estiver completa (sem lacuna maior que 3× o intervalo).

Se o processo terminar rápido demais para amostrar, CPU/memória ficam **N/A** com motivo
`too_short_to_sample`. O tempo de parede não é reclassificado por causa disso.

## 3. Persistente (`persistent`)

- O tempo total de parede **não** é métrica de desempenho, porque é fixado pela janela.
- **CPU e memória** são válidas somente se a coleta cobrir a janela inteira, os dois lados
  tiverem séries completas e a árvore de processos estiver identificada (PID raiz + filhos).
- Permanecer ativo até o fim da janela **não** significa equivalência funcional. Isso é
  avaliado só pela camada de fidelidade comportamental.

## 4. Classificação do término (mutuamente exclusiva)

| Código | Significado |
|--------|-------------|
| `natural_completion` | o processo terminou sozinho dentro do limite |
| `timeout` | `short_lived` excedeu o timeout e foi encerrado |
| `controlled_termination` | `persistent` chegou ao fim da janela e foi encerrado pelo runner |
| `crash` | término anormal (código de exceção NTSTATUS, ex.: `0xC0000005`) |
| `launch_failure` | o processo não iniciou |
| `collector_failure` | o processo rodou, mas a coleta falhou |
| `no_data` | ausência de dados, com `missing_reason` obrigatório |

Um timeout nunca é marcado como conclusão natural (regra crítica no validador).

## 5. Regras por condição

- `NAT` não pode conter indícios de Pin (regra crítica do validador).
- Cada condição `TMW_*` individual deve ter exatamente um módulo ativo; `TMW_ALL` deve ter os cinco; `TMW0` nenhum.
- Para a condição `PIN`: só entra nos contrastes se o probe a validou; caso contrário, os contrastes dependentes dela são omitidos com justificativa registrada.

## 6. Contrastes e proporções

- Contrastes são **pareados dentro do mesmo binário** (ver `protocol.md`).
- Proporções (conclusão, falha, supressão) são reportadas como numerador/denominador, porcentagem e IC de 95% (Wilson). Nunca apenas "100%".
- Quando a baseline do contraste é próxima de zero, reporta-se a diferença absoluta e sinaliza-se denominador instável; não se depende só da variação percentual.
