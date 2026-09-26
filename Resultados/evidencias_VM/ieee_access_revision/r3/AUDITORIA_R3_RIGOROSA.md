# Auditoria rigorosa — Reviewer 3 (IEEE Access)

Classificação por comentário com três eixos separados (não basta “FEITO” no pacote):

1. A evidência experimental sustenta a resposta?
2. O texto proposto não extrapola a evidência?
3. A alteração aparece no manuscrito (não só na Response Letter)?

Classificação global por ponto = o pior eixo ainda aberto.

| Ponto | Evidência | Texto proposto | Manuscrito Overleaf | GLOBAL |
|-------|-----------|----------------|---------------------|--------|
| R3-1 AntiDebug matched | ATENDIDO | ATENDIDO (se purge unvalidated) | PARCIAL até colar 7.1 + purge | PARCIALMENTE ATENDIDO |
| R3-2 Re-exec 29% / bias | ATENDIDO (9/31=29.0%) | ATENDIDO | PARCIAL até colar 7.2 | PARCIALMENTE ATENDIDO |
| R3-3 IC / descritivo | ATENDIDO (N=30 IQR+IC95%) | ATENDIDO | PARCIAL até colar 7.3 | PARCIALMENTE ATENDIDO |
| R3-4 Tabela related | ATENDIDO (arquitetural; sem H2H) | ATENDIDO (sem superioridade) | PARCIAL até tab:related-r3 | PARCIALMENTE ATENDIDO |
| R3-5 Language/format | n/a | Checklist pronto | NÃO até passada no Overleaf | NÃO ATENDIDO |

## Detalhe AntiDebug

- Evidência matched: baseline `-gdb -q` vs treatment `-gdb -dd -q`, 3 reps + Pin-only.
- Isso é suficiente para **não** classificar o módulo como unvalidated **desde que** o
  manuscrito inteiro deixe de dizer unvalidated/inconclusive para AntiDebug.
- Se sobrar “unvalidated” em Abstract/Results/Discussion, R3-1 volta a NÃO ATENDIDO
  no eixo manuscrito (mesmo com figura correta na Response).

## Detalhe SkewMask / 29%

- Fixed-1 recount: 22/31 first-attempt; 9/31 (29.0%) needed re-exec no protocolo antigo.
- Bias: reter só trials que eventualmente passam o limiar infla sucesso aparente.
- Mitigação: first-attempt report + descriptive corpus + fixed-N=30 retendo todas as runs
  (IQR + IC95%).

## Detalhe related systems

- Tabela arquitetural vs Arancino / COBAI / Peekaboo é adequada.
- Proibido: “superior”, “outperforms”, claims empíricos H2H inexistentes.
- Redação segura: “In our comparison, TOMWare.M combines...”.

## Checklist de integração no manuscrito (antes do resubmit)

- [ ] Colar 7.1 AntiDebug matched; remover unvalidated/inconclusive AntiDebug em TODO o PDF
- [ ] Colar 7.2 (§29% / selection bias / fixed-N mitigation)
- [ ] Colar 7.3 (IQR + IC95% oracle; corpus = descriptive)
- [ ] Inserir `tab:related-r3` + parágrafo 7.4 (sem superioridade)
- [ ] Language pass: -gbd→-gdb; knobs; hífens; captions; espaços
- [ ] Response Letter R3 alinhada ao texto colado (não só ao pack)

## Veredito operacional

- **Nova campanha VM para R3:** não.
- **Bloqueio atual:** integração Overleaf (eixos 2–3), especialmente purge unvalidated +
  language pass.
- **Quando o checklist acima estiver marcado:** R3 fica ATENDIDO no manuscrito e nas evidências.
