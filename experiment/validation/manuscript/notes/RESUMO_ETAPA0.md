# Etapa 0 � Artigo atual � c�digo e dados

**PDF analisado:** `Mitigating_...__REVISION_ (1).pdf` (Downloads, 22/10/2026 13:05)  
**SHA-256:** `0FEF4163C6153382AD94E350DAE742105AD9515C84C0D3C2BA03F84FA2AE5851`  
**P�ginas:** 23  

Este ficheiro � **byte a byte o mesmo** que `Mitigating_...__REVISION_.pdf` de 13/10 no reposit�rio. O Overleaf ainda n�o incorporou a campanha de 9.000 runs nem o timing N=30.

Tabela completa: `artigo_vs_codigo.csv` (38 afirma��es).

## O que j� est� coerente com o c�digo (manter)

A descri��o da ferramenta no artigo bate com o C++ atual:

- Cinco m�dulos e knobs `-dd -dp -de -dm -do`; `-da` liga os cinco sem `-go`.
- AntiDebug: s� `BeingDebugged` e `NtGlobalFlag` via TEB/PEB; offsets 0xBC (x64) / 0x68 (x86); `-gdb` � registado **antes** de `-dd`.
- ProcessEnum: `Process32*` / `Module32*` / `GetModuleHandleA/W`; esconde `pin.exe`, `pinvm.dll`, `pinipc.dll`, `TOMWare.dll`; n�o toca em `NtQuerySystemInformation`.
- SanitizePinEnvVars: bloco do PEB antes do CRT; `PIN_` ? `ZZZ_` no s�tio, mesmo comprimento.
- InstMemcmpMask: as 12 rotinas listadas; segundo operando; comprimento exato; assinaturas default `PIN_`, `pin.exe`, `pinvm.dll`, `pinipc.dll`.
- SkewMask: `Sleep` / `SleepEx` / `NtDelayExecution`; desconto em QPC, `GetTickCount(64)`, `GetSystemTimePreciseAsFileTime`, `QueryInterruptTimePrecise`; sem RDTSC.
- Oracle de timing: `Sleep` 50 ms � 40 ? limiar 3.000; par `-go` vs `-go -do`.
- Sem benchmark experimental com Arancino / COBAI / Peekaboo.
- Compatibilidade ? equival�ncia comportamental; o artigo j� diz isso.
- Or�culos do corpus **n�o** provam que o malware usou os 5 checks.

## O que diverge e o Overleaf tem de substituir

O artigo ainda descreve o protocolo **antigo**. O c�digo e os dados atuais j� s�o outro protocolo.

| Artigo (este PDF) | C�digo / dados atuais |
|---|---|
| 31 PE (17+14), 155 combina��es, 3.100 lan�amentos | 100 PE (25+25+25+25), 9 condi��es, 9.000 JSON |
| Janela persistente 10 s | 60 s; timeout curto 120 s |
| Baseline = Pin + TOMWare com m�dulo off | Escada NAT / EMPTY / TMW0; Pin sem `-t` � inv�lido |
| M�dulos s� individuais | Tamb�m existe TMW_ALL (`-da`) |
| 155/155 �passaram� | Desfechos mistos; `natural_exit = 0`; 6.517 rotulados `exception_crash` com `exit_code = null` (bug do coletor) |
| SkewMask 9/31 re-execu��es | N=30 fixo: GO 11/30 abaixo do limiar (mediana 3.083,210); GO_DO 30/30 (2.104,770); TMW0 30/30 (2.433,285) |
| AntiDebug 3+3 | C�digo do pareamento correto; CSV de 21/10 tem **1 run por condi��o** |
| ?87,2 % WS / ?38,5 % CPU | SkewMask **estica** o wall-clock (benigno persistente +55,5 s); n�o � ganho |
| Sem IC | J� h� bootstrap 95 % e Wilson |
| Future work 4, 5 e parte do 7 (`-da`, NAT/EMPTY, corpus+IC) | J� feitos nesta campanha |
| TMW_DM agrup�vel em �IC inclui 0� | WS malignos curtos +0,451 MB [0,049; 0,805] **n�o inclui zero** |

## O que o artigo acerta em tom, mas os n�meros est�o velhos

- A regra de validade da m�trica **n�o** estava no `experiment.config.json`. O artigo j� admite que foi formalizada na revis�o. Isso deve continuar expl�cito; n�o digam que era a priori.
- �N�o h� equival�ncia comportamental� continua correto. O `FidelityProbe` � **outro** pintool e n�o corre ao mesmo tempo que o TOMWare.
- Contagens do `TestMemoryScan` (212 / 11 / 14 / 18) n�o foram reconfirmadas na VM de 21/10 (excerpt truncado). Reexecutar na Etapa 4.

## Cartas que **n�o** devem ir aos revisores

Os PDF `Access-2026-38745_Response_to_Reviewers.pdf` e a vers�o PT, mais o `MANUSCRIPT_REPLACEMENTS.md`, herdaram erros meus:

1. Tratar `crash_exit` como crash real.
2. Medianas do N=30 pelo elemento inferior do par central, n�o a mediana convencional.
3. Misturar AntiDebug 3+3 do artigo com o 1+1 do CSV.
4. Dizer que `sample_count > 0` estava no config a priori.
5. Tratar o IC do TMW_DM (WS, malignos curtos) como se inclu�sse zero.

Regenerar cartas s� depois das Etapas 2�9.

## Checkpoint para o coautor

1. Confirmar que este PDF � de facto o Overleaf atual (hash acima). Se houver outra exporta��o, enviar.
2. Concordar que **nenhuma** frase de 31 / 3.100 / 10 s / 155/155 / ?87 % / 9/31 entra na vers�o que vai � IEEE.
3. A descri��o dos m�dulos (Sec. III�V) pode ficar, com revis�o pontual.
4. Pr�ximo passo no host, sem VM: Etapa 1 (congelar hashes) e Etapa 2 (auditar os 9.000 com as defini��es corretas).
