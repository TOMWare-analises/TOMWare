# Protocolo Experimental da TOMWare.M

**Documento Normativo do Experimento**  
**Artigo:** IEEE Access (Access-2026-38745)  
**Projeto:** TOMWare.M — Avaliação Experimental Rigorosa e Auditável

> **Âmbito:** este documento é o protocolo da campanha **100 PE / 9 000 execuções**.
> O pacote JCVHT 17+14 / 10 s e os oráculos N=30 são outra campanha (mesma DLL
> `4BBC6270`). Identidade e hashes: README da raiz, secção Reproduce. Não misturar células.

---

## 1. Objetivos Científicos e Questões de Pesquisa

O desenho experimental foi formulado para responder de forma desacoplada e independente às seguintes questões:

1. **Q1 — Custo do Intel Pin:** Qual o overhead da execução sob o motor Pin em relação à execução nativa (`PIN - NAT`)?
2. **Q2 — Custo de carregar uma Pintool:** Qual o custo marginal de instanciar uma ferramenta de análise nula (`EMPTY - PIN` ou `EMPTY - NAT`)?
3. **Q3 — Custo da infraestrutura defensiva:** Qual o custo da TOMWare.M carregada com todas as contramedidas desativadas (`TMW0 - EMPTY`)?
4. **Q4 — Custo incremental por contramedida:** Qual o overhead específico adicionado por cada módulo isolado (`TMW_DD - TMW0`, `TMW_DP - TMW0`, `TMW_DE - TMW0`, `TMW_DM - TMW0`, `TMW_DO - TMW0`)?
5. **Q5 — Custo da ativação conjunta:** Qual o impacto da ativação simultânea dos cinco módulos (`TMW_ALL - TMW0`)?
6. **Q6 — Acionamento efetivo dos módulos:** Cada contramedida é efetivamente acionada durante a execução ou permanece passiva (contadores internos)?
7. **Q7 — Modificação comportamental:** A ativação da contramedida preserva a fidelidade operacional da aplicação (processos, APIs, I/O, saída)?
8. **Q8 — Sobrevivência e conclusão:** A aplicação encerra naturalmente ou permanece observável sem falhas operacionais?
9. **Q9 — Supressão nos oráculos funcionais:** Os indicadores exercidos por estímulos conhecidos são mascarados sob condições casadas (`-gdb` vs `-gdb -dd`; `-go` vs `-go -do`)?
10. **Q10 — Auditabilidade e ausência de viés:** Todos os resultados brutos são preservados sem descarte baseado em resultado favorável/desfavorável?

---

## 2. Condições Experimentais

As condições são configuradas via `conditions.csv`:

| Código | Intel Pin | Ferramenta | Parâmetros | Finalidade |
|---|---|---|---|---|
| `NAT` | Não | Nenhuma | *(nenhum)* | Linha de base da aplicação sem instrumentação |
| `PIN` | Sim | Nenhuma | *(sem -t)* | Custo puro do motor Pin (validado por probe) |
| `EMPTY` | Sim | `EmptyPinTool.dll` | *(nenhum)* | Custo mínimo de carregar uma Pintool passiva |
| `TMW0` | Sim | `TOMWare.dll` | `-q` | Infraestrutura TOMWare.M com defesas desligadas |
| `TMW_DD` | Sim | `TOMWare.dll` | `-dd -q` | Efeito isolado do AntiDebug |
| `TMW_DP` | Sim | `TOMWare.dll` | `-dp -q` | Efeito isolado do ProcessEnum |
| `TMW_DE` | Sim | `TOMWare.dll` | `-de -q` | Efeito isolado do SanitizePinEnvVars |
| `TMW_DM` | Sim | `TOMWare.dll` | `-dm -q` | Efeito isolado do InstMemcmpMask |
| `TMW_DO` | Sim | `TOMWare.dll` | `-do -q` | Efeito isolado do SkewMask |
| `TMW_ALL` | Sim | `TOMWare.dll` | `-da -q` | Efeito combinado de todos os 5 módulos |

*Nota sobre a condição PIN:* O Intel Pin por padrão requer uma ferramenta (`-t`) para carregar o executável em modo JIT. O probe experimental testa `pin.exe -- app.exe`. Caso `pin.exe` recuse a execução sem `-t`, a condição `PIN` é documentada no manifesto como tecnicamente não-suportada, e `EMPTY` passa a ser a linha de base mínima do Pin (9 condições operacionais).

---

## 3. Desenho Amostral e Randomização em Blocos

Para evitar confundimento entre condição experimental e ordem/momento de execução:

1. **Blocos Amostrais:** Cada bloco corresponde a um par `(sample_id, repetition)`.
2. **Ordem Randomizada:** Dentro de cada bloco, todas as condições válidas são executadas exatamente uma vez, em ordem pseudoaleatória gerada a partir de uma semente registrada.
3. **Semente Gravada:** A semente é armazenada em `randomization_seeds.csv` e no cabeçalho de cada execução, permitindo reprodução determinística da sequência.
4. **Execução Estrita:** A ordem gerada no plano nunca é alterada por causa de um resultado inesperado. Falhas e timeouts são gravados exatamente na posição em que ocorreram.

---

## 4. Unidade de Isolamento e Restauração de Ambiente

Para evitar contaminação cumulativa entre execuções:

- **Unidade de Restauração:** Snapshot limpo revertido a cada **bloco** (amostra + repetição).
- **Justificativa Técnica:** Reverter o snapshot por bloco (10 condições) equilibra rigor de contenção e viabilidade temporal, garantindo que cada amostra inicia sua rodada a partir do mesmo estado idêntico do sistema operacional.
- **Rede:** Interface de rede desativada ou restrita a host-only sem rota externa.
- **Checagem de Resíduos:** O runner executa uma varredura de processos residuais antes de iniciar cada bloco e após cada execução (`taskkill /F /T` para instâncias remanescentes).
- **Identificação:** O `snapshot_id` e o status de conclusão da restauração são registrados em cada JSON individual.

---

## 5. Perfis Temporais e Janelas de Observação

1. **Aplicações de Curta Duração (`short_lived`):**
   - Aguardam conclusão natural.
   - Timeout fixado em 120 segundos.
   - Registram se concluíram naturalmente, se sofreram timeout ou se houve exceção/crash.
   - Preservam hashes SHA-256 de stdout e stderr.

2. **Aplicações Persistentes (`persistent`):**
   - Janela de observação padronizada em 60 segundos.
   - Coleta contínua de série temporal de recursos (intervalo de 200 ms).
   - Ao término da janela, encerramento controlado pelo runner (`controlled_termination`).
   - Não se atribui equivalência funcional ao simples fato de o processo permanecer ativo.

---

## 6. Oráculos Funcionais

Campanha independente realizada sobre `Resultados/Apps-Teste/`:

- **AntiDebug:** Comparação casada sob mesmo estímulo:
  - Baseline: `pin.exe -t TOMWare.dll -gdb -q -- TestAntiDebug.exe`
  - Tratamento: `pin.exe -t TOMWare.dll -gdb -dd -q -- TestAntiDebug.exe`
  - Controle negativo: Pin-only sem `-gdb`.
- **SkewMask:** Comparação casada com protocolo fixo $N=30$ sem descarte de amostras:
  - Baseline: `pin.exe -t TOMWare.dll -go -q -- TestOverhead.exe`
  - Tratamento: `pin.exe -t TOMWare.dll -go -do -q -- TestOverhead.exe`
  - Relato da taxa de compensação (% de ticks abaixo do limiar 3000), mediana, IQR e IC de 95%.
- **ProcessEnum:** `TestProcessEnum.exe` com Tool Help (`pin.exe` filtrado).
- **SanitizePinEnvVars:** `TestGetEnvironments.exe` (variáveis `PIN_*` renomeadas para `ZZZ_*`).
- **InstMemcmpMask:** `TestMemoryScan.exe` (interceptação de `memcmp`).

---

## 7. Análise Estatística no Nível do Binário

As repetições estão aninhadas no executável. O procedimento estatístico obrigatório consiste em:

1. **Nível da Execução:** Cálculo das métricas brutas (tempo monotônico, CPU usuário/kernel, pico WS, pico private).
2. **Nível do Binário:** Cálculo da mediana das repetições válidas para cada par `(binário, condição)`.
3. **Contrastes Pareados:** Diferenças calculadas dentro do mesmo binário ($TMW_X - TMW0$, etc.).
4. **Agregação por Estrato:** Mediana, IQR e intervalo de confiança bootstrap de 95% no nível dos binários.
5. **Proporções:** Taxas de conclusão e supressão acompanhadas de intervalo de confiança Wilson de 95%.
6. **Não-Dependência de Percentuais Instáveis:** Quando a linha de base for próxima de zero, a diferença absoluta é reportada obrigatoriamente.
