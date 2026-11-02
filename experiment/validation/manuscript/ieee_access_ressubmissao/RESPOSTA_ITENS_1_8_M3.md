# Resposta item a item — Access após as 9 células access_m3_cases

Não enviar à IEEE. Não é o suplemento double-blind. Sem malware. Sem as 9.000.
Citação: git a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3.
DLL 4BBC6270. Launcher `pin\pin.exe` 920A730A (`pin_sha256_matches_campaign=true` nas 9).
Campanha `access_m3_cases`, script `m3c.4`, N=1, 60 s, `-mc` ligado, rede off, snapshot `tomware_go`.
`identified=false` e `chain_complete=false` em todas. Não se acrescentam amostras.

SHA a priori (IAT é pista, não caso):
- MAL_07 `153e1147…19800d`
- MAL_13 `2a2b6b75…ebb9e24`
- MAL_08 `1693df9d…417b6d38`

## 1. Relacionar malware, verificação e contramedida

**Executado. Resultado negativo / inconclusivo. Não resolvido.**

A sequência pedida (amostra chamou a API → hook incrementou → resultado mudou → módulo identificado) **não aparece em nenhuma célula**.

| Amostra | TMW0 | TMW_DP (`-dp`) | TMW_DO (`-do`) |
|---|---|---|---|
| MAL_07 | JSON ok; todos os contadores 0; crash `0xC0000005` + WerFault + SINGLE_STEP_TRAP | **INVALID:** Pin não mapeou a DLL (Win32 216) | vivo 60 s; JSON ausente |
| MAL_13 | vivo 60 s; JSON ausente | vivo 61 s; JSON ausente; sem 216 | vivo 60 s; JSON ausente |
| MAL_08 | vivo 62 s; JSON ausente | vivo 61 s; JSON ausente; sem 216 | vivo 60 s; JSON ausente |

Só duas células escreveram `module_events.json` (MAL_07 TMW0 e MAL_07 TMW_DP). TMW0 não instala hooks `-dp`/`-do`. TMW_DP do MAL_07 é inválido. Nas restantes o JSON não foi descarregado (Pin morto no fim da janela). IAT de Toolhelp/SleepEx **não** é ramo executado. Isto **não** autoriza escrever que os 100 PE usam as cinco checagens.

## 2. Comportamento adicional em casos seleccionados

**Executado. Resultado negativo. Não resolvido.**

Nenhuma célula tem extra versus TMW0 (ficheiro com hash, Run/RunOnce, TCP, filho que não seja pin/conhost).

O único “filho extra” absoluto foi `WerFault.exe` no MAL_07 TMW0 — relator de crash, não payload. Árvore típica: `pin.exe` → `pin.exe` → sample + `conhost`. Vivo a 60 s não é desempacotamento, configuração, ficheiro, registo, rede nem nova fase.

Cadeia completa: **0/6** pares TMW0×knob.

## 3. Explicar comportamentalmente o SkewMask

**Executado nas três SHA. Sem prova de interceptação. Não resolvido como ganho.**

| Amostra | TMW0 ms | TMW_DO ms | extra vs TMW0 | Leitura |
|---|---|---|---|---|
| MAL_07 | 10 969 (crash) | 60 204 (vivo) | não | duração maior = espera/estado; JSON do TMW_DO ausente; sem artefacto |
| MAL_13 | 60 329 | 60 109 | não | mesma janela; SkewMask não alongou nem produziu extra |
| MAL_08 | 62 031 | 60 422 | não | mesma janela; idem |

Sem `sleep_calls` / `time_queries` / `corrections` demonstrados no TMW_DO (JSON ausente). r43d (BEN_28/46/47) continua à parte e é benigno.

## 4. Coerência temporal de SkewMask

**Não corrido. Limitação.** Timeouts sob Pin nas esperas concorrentes/sobrepostas/alertáveis continuam inconclusivos. `SkewMask.cpp` não foi alterado. Não se copiam células JCVHT.

## 5. Pin sem Pintool no corpus

**Limitação.** Só o controlo técnico N=3 em `TestAntiDebug` (920A730A, 3/3 exit 0, 1900–2963 ms). Não é braço dos 100 PE. `campaign.json` `pin_condition_valid=false` não foi invertido.

## 6. Metadados incompletos

**Limitação.** `Trojan_Bazaar` / `Backdoor_Bazaar`; packer `unknown`; `targeted_evasion=unverified` nos 50 MAL. Estas 9 células não identificaram técnica em runtime.

## 7. Comparação experimental externa

**Limitação / trabalho futuro.** Sem bake-off Arancino, COBAI ou Peekaboo. Arancino: Pin 2.14, 32-bit; corpus Access 100% x64.

## 8. Critérios prospectivos

As três SHA e os três braços foram fixados **antes** desta corrida. A campanha das 9.000 continua post hoc. Não se substitui por uma recolha nova do corpus.

## O que a carta pode dizer

Correram-se 3 PE maliciosos a priori, TMW0 / TMW_DP / TMW_DO, launcher da campanha, `-mc` ligado. Não se observou a cadeia verificação → módulo → comportamento extra. Persistência a 60 s e a árvore pin+conhost não são progresso. IAT não é execução. Os itens 4–8 permanecem limitações.

## O que a carta não pode dizer

- os 100 usam as cinco checagens
- IAT de MAL_07/13/08 = verificação executada
- TMW_DO mais longo no MAL_07 = ganho do SkewMask
- vivo 60 s / pin+conhost = comportamento recuperado
- `identified=true`
- bake-off Arancino
- as 9.000 revalidadas por estas 9 células
