# TOMWare.M — Infraestrutura experimental reprodutível

Mede, de forma auditável e sem seleção por resultado, o custo e os efeitos das cinco
contramedidas da TOMWare.M, separando: custo do Intel Pin, da Pintool vazia, da
infraestrutura TOMWare.M (módulos off), de cada contramedida e da ativação conjunta.

Duas campanhas medidas neste tree — **não misturar células**:

| Campanha | Amostras | Janela | Tabelas | DLL |
|----------|----------|--------|---------|-----|
| JCVHT 31-PE | 17 benignos + 14 infectados | 10 s | `experiment/results/corpus/` e `oracles/` | `4BBC6270` |
| Access 9 000 | 100 PE (50+50) × 9 × 10 | 120 s curtas / 60 s persistentes | `experiment/results/campaign/corpus_aligned_10k/` | `4BBC6270` |

Identidade: Pin 3.28.98749, snapshot `tomware_go`, tag `jcvht-dll-4bbc6270-candidate` (`a22e01d`).
O `main` atual (`242f800`) só acrescenta o hook de 4 argumentos em `_memicmp_l`; `SkewMask.cpp`
não muda. Como repetir: README da raiz, secção Reproduce.

## Decisões de desenho

1. **Isolamento:** restauração de snapshot por **bloco** (amostra+repetição), orquestrada
   **no host** (`experiment/scripts/host/Run-HostCampaign.ps1`). A VM é descartável;
   os JSON são copiados para o host antes de cada revert. Não correr a campanha só
   numa janela interativa do convidado.
2. **Stack:** **runner + coletores em PowerShell** (na VM, reusa `scripts/lib/TomwareBenchmark.ps1`);
   **plano + validadores + estatística + figuras em Python** (host). Separação: PowerShell
   executa/coleta; Python planeja/valida/analisa.
3. **Corpus:** `experiment/corpus/corpus.csv` é o catálogo dos **100 PE** da campanha
   9 000. O pacote JCVHT 17+14 é outro recorte (10 s); não substituir um pelo outro.
4. **Condição PIN:** probe tenta `pin.exe` sem tool, registra o erro; se inválida, usa
   `EMPTY` como baseline mínima de Pin (⇒ 9 condições). A decisão fica no manifesto da campanha.

## Camadas

| Papel | Tecnologia | Caminho |
|------|-----------|---------|
| Plano randomizado por blocos | Python | `experiment/scripts/planner/` |
| Runner + coletores | PowerShell | `experiment/scripts/runner/`, `experiment/scripts/collectors/` |
| Validadores | Python | `experiment/scripts/validators/` |
| Estatística + figuras/tabelas | Python | `experiment/scripts/analysis/` |
| Testes unitários e de integração | Python | `experiment/scripts/tests/` |
| Contadores internos dos módulos | C++ (TOMWare.dll) | `TOMWare/*.cpp` (instrumentação opcional) |
| Pintool vazia | C++ | `EmptyPinTool/` (raiz do repositório) |

## Fluxo

```
corpus.csv + conditions.csv + experiment.config.json
        │  (Python planner, semente registrada)
        ▼
campaigns/<id>/execution_plan.csv  ──►  PowerShell runner (VM)
        │                                     │ coleta por execução
        │                                     ▼
        │                         raw/runs/*.json  (atômico)  + resources/ behavior/ module_events/ stdout/ stderr/
        ▼                                     │
Python validators  ◄──────────────────────────┘
        │  (falha explícita em regra crítica)
        ▼
processed/*.csv  ──►  Python analysis  ──►  reports/tables + figures
```

## Layout do repositório (o que é o quê)

O caminho `TOMWare\TOMWare` **não é um erro de cópia**: a pasta de fora é a raiz do repositório (solução Visual Studio + Pin + `experiment/`); a de dentro é o código C++ da Pintool, como o `.sln` espera.

```
tomware-melhorias/                 ← workspace local
  TOMWare/                         ← raiz do repositório (RepoRoot / C:\TOMWare na VM)
    TOMWare/                       ← fonte C++ da Pintool (.vcxproj)
    EmptyPinTool/  FidelityProbe/
    pin/                           ← Intel Pin 3.28
    x64/Release/                   ← DLLs compiladas (**fora do git**; copiar 4BBC6270)
    samples/benign|infected        ← corpus (exe benignos; zip maliciosos)
    experiment/                    ← campanha + oráculos (produto; não é pasta de artigo)
    Resultados/Apps-Teste/         ← oráculos funcionais
    config/signatures.txt
```

A infraestrutura experimental vive em `experiment/`:

```
experiment/
  config/
    experiment.config.json           # caminhos, repetições, timeouts, amostragem, semente
  protocol/
    protocol.md                      # desenho completo e formal do experimento
    conditions.csv                   # condição → template de comando (sem comando fixo no código)
    oracle_conditions.csv            # pareamento casado dos oráculos funcionais
    validity_rules.md                # regras a priori de validade de métrica
    empty_tool_and_pin_probe.md      # documentação da EmptyTool e probe PIN
    randomization_seeds.csv          # registro persistente de sementes por campanha
  corpus/
    corpus.csv                       # amostras + metadados (gerado/preenchido; nada inventado)
    corpus.schema.md                 # esquema dos 22 atributos
    exclusions.csv                   # registro de exclusões justificadas
  environment/
    build_manifest.json              # hashes das ferramentas e ambiente
  schemas/
    run_record.schema.json           # esquema formal do JSON de cada execução
  campaigns/<campaign_id>/           # plano e manifesto (campaign.json, execution_plan.csv)
  results/                           # único sítio de tabelas (corpus / oracles / campaign)
  scripts/
    planner/                         # generate_plan.py
    runner/                          # Run-Campaign.ps1, Invoke-SingleRun.ps1
    collectors/                      # ProcessCollector.ps1
    validators/                      # validate_campaign.py
    analysis/                        # consolidate_and_analyze.py
    tests/                           # test_planner.py, test_validator.py, test_analysis.py, test_integration_benign.py
    sanitize_ps1_ascii.py            # utilitário de compatibilidade PS 5.1
    generate_build_manifest.py       # gerador de manifesto de build
```

Cada execução grava um JSON individual (primeiro em `.tmp`, depois `move` atômico) e uma
linha no índice consolidado. Hashes SHA-256 são gerados para executáveis, `TOMWare.dll`,
`EmptyPinTool.dll`, Pin, configs, scripts, brutos e tabelas.

Tabelas medidas: `experiment/results/`. Como repetir: README na raiz do
repositório (secção Reproduce). Os traces `raw/` e `ev_*` não vão para o git.
