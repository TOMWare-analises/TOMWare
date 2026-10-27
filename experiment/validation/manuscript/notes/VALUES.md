# Etapa 9 � valores oficiais (IEEE Access-2026-38745)

Fonte unica: `MANUSCRIPT_VALUES.json` (gerado por `build_manuscript_values.py` a partir dos CSV auditados).
Os 9000 JSON brutos nao foram mexidos. PDF Overleaf ainda e o de 13/10 (`0FEF4163�`).

## Identidade

Pin 3.28.98749. Semente 705851366. 100 PE � 9 � 10 = 9000. Janela persistente 60 s, timeout curto 120 s.
DLL campanha `4bbc6270�`. Snapshot `tomware_go`. Bootstrap 2000. Mediana convencional.
Regra de recursos: **post hoc** (`sample_count > 0`).

## Table 3 � corpus (so o verificavel)

50+50; 25+25+25+25. **100/100 x64.** Fonte: Windows_Environment / MalwareBazaar (14/10/2026).
SHA-256, tamanho, perfil: sim. `targeted_evasion`: benigno `none`, maligno `unverified`.
Familia no CSV e rotulo grosso (`Windows_Console_App` / `Windows_GUI_App` / `Trojan_Bazaar` / `Backdoor_Bazaar`) � **nao** e consenso VT. Nao inventar familias.

## Table 4 � oraculos

AntiDebug 3+3: `-gdb -q` 3/3 positivo; `-gdb -dd -q` 3/3 zero. NAT/TMW0 negativos.
`-da` nos 5 oraculos: exit 0. TestOverhead 2040,7 < 3000.
Timing N=30 (hash `76208218�`, nao repetir): TMW0 2433,285 (30/30); GO 3083,210 (11/30); GO_DO 2104,770 (30/30).
Wilson 11/30 = 36,7% [21,9; 54,5]; 30/30 = 100% [88,6; 100].

## Table 5 � desfechos 9000 (n=250)

6517 = **termino sem codigo** (bug do coletor). Crash verdadeiro nos 9000: **0**.
`natural_exit` = 0. Timeout 877. Janela 1355. Launch fail 251.

Sobrevivencia persistente (Wilson 95%):

- Benigno: NAT 8,0% [5,2; 12,0]; EMPTY 11,2% [7,9; 15,7]; TMW0 9,6% [6,5; 13,9]; TMW_DO 52,8% [46,6; 58,9]; TMW_ALL 56,4% [50,2; 62,4].
- Maligno: NAT 54,4% [48,2; 60,5]; EMPTY 32,4% [26,9; 38,4]; TMW0 32,8% [27,3; 38,8]; TMW_DO 57,6% [51,4; 63,6]; TMW_ALL 64,0% [57,9; 69,7].

Curto: termino de protocolo ?96,8% em todos os bracos. Nao escrever �crash-exit�.

## Table 7 � deltas (tratamento ? TMW0), mediana de 25, bootstrap 95%

Usar `n_pairs_*`, nao fingir n=25 quando for 23 ou 2.

| Contraste | Estrato | ? parede (ms) | ? WS (MB) |
|---|---|---|---|
| EMPTY ? NAT | Benigno curto | +1166 [955; 2553] | n_pairs_ws=**2** � nao publicar como n=25 |
| TMW0 ? EMPTY | Benigno curto | +151 [26; 270] | +5,7 [4,9; 8,9] |
| TMW_DP ? TMW0 | Benigno curto | +3844 [3427; 4088] | +0,5 [0,1; 1,0] |
| TMW_DO ? TMW0 | Benigno curto | +31669 [13744; 51072] | +0,7 [?0,2; 2,2] |
| TMW_DO ? TMW0 | Benigno persist. | +55452 [30685; 57031] | ?3,2 [?58,3; +0,4] (IC inclui 0) |
| TMW_DO ? TMW0 | Maligno persist. | +37387 [26146; 42770] n_pairs=23 | ?22,7 [?94,9; ?10,7] |
| TMW_ALL ? TMW0 | Benigno persist. | +55512 [38005; 56972] | ?5,1 [?74,6; 0,0] |
| TMW_DM ? TMW0 | Maligno curto | parede IC inclui 0 | **+0,451 [0,049; 0,805]** (nao e zero) |

Carta antiga tinha TMW_DO maligno persistente +37057 [131; 42770] � **errado**. Usar a linha auditada.

Parede persistente **nao** e metrica de desempenho (SkewMask estica a janela).

## Etapas 5�8 (nao misturar com os 9000)

- E5: 537/600 JSON; DLL live-dump `3A3AFB6F�`. TMW_ALL: AD 269/269, env 259/269, memcmp 146/269 **0 match**, Skew 39/269, ProcessEnum **0**. Nao: �o malware usou os 5 checks�.
- E6: 120/120; TMW0 vs TMW_ALL exit+stdout iguais **22/30**. Sem equivalencia de API.
- E7: 1800/1800, coletor 2.1; exit inteiro 1600; nulo 200; AV `0xC0000005` = 105 (5,8%). Nao reescreve os 9000.
- E8: bloqueio Arancino (`08_arancino/BLOQUEIO.md`).

## Future work (colar no �VIII)

Riscar do paper: itens 4 (`-da`), 5 (NAT/EMPTY), metade do 7 (corpus+IC), N=30, AntiDebug 3+3.

Manter: NtQueryInformationProcess; NtQuerySystemInformation; RDTSC/RDTSCP; fidelidade por traces de API.

**Acrescentar (pedido 23/10):** (a) TOMWare Win32 + Pin 3.28 ia32, oraculos 32-bit, corpus 32-bit opcional; (b) bake-off com Arancino num protocolo 32-bit partilhado (Pin 2.14+VS2010 ou porto documentado). Os 9000 x64 **nao** sao esse bake-off.

Texto pronto: `FUTURE_WORK.md`.
