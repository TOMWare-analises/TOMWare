# Overleaf — o que colar (Access-2026-38745)

Enviar ao colaborador (nao a IEEE): o PDF unico de instrucoes + as duas cartas.

1. `Access-2026-38745_Overleaf_Instructions.pdf`
2. `Access-2026-38745_Response_to_Reviewers.pdf` (carta oficial EN)
3. `Access-2026-38745_Resposta_aos_Revisores.pdf` (PT, ajuda)
4. Opcional: este ficheiro, `MANUSCRIPT_REPLACEMENTS.md`, `09_values/FUTURE_WORK.md`

Numeros: so `experiment/results/oracles/manuscript_values.json`.
32-bit / Arancino: trabalho futuro, depois do envio.

## Substituir no `.tex`

1. Abstract inteiro — medianas 3,083.210 / 2,104.770; 100 PE; 9.000; 60 s / 120 s. Sem “curtos sao crash”.
2. Todas as frases 31 / 3.100 / 155 / 17+14 / 10 s.
3. Tabela 4 SkewMask: 11/30 vs 30/30. Apagar 9/31.
4. Tabela 5: apagar 155/155. Colar sobrevivencia 60 s (carta, Table 2).
5. Tabela 7: apagar −87,2 / −38,5. TMW_DO maligno persistente **+37.387 [26.146; 42.770]** (n=23). TMW_DM WS +0,451.
6. §VI: 120/60; NAT–EMPTY–TMW0; `sample_count>0` e **post hoc**.
7. §VIII: `FUTURE_WORK.md` (32-bit + bake-off Arancino depois).
8. Conclusao: sem transparencia, sem “ganhamos do Arancino”, sem “os 100 usavam os 5 checks”.

Amarelo em **todas** as frases alteradas, incluindo abstract. Depois PDF limpo.

## Nao misturar

- Campanha IEEE 9000 ≠ JCVHT.
- Oraculos ≠ corpus 100 PE.
- Etapa 5 (outra DLL) ≠ 9000. Etapa 7 (1800) nao reescreve os 9000.
