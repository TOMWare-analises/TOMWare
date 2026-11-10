# Overleaf — what to paste (Access-2026-38745)

Send to the collaborator (not to IEEE): the single instructions PDF + the two letters.

1. `Access-2026-38745_Overleaf_Instructions.pdf`
2. `Access-2026-38745_Response_to_Reviewers.pdf` (official EN letter)
3. `Access-2026-38745_Resposta_aos_Revisores.pdf` (PT, aid)
4. Optional: this file, `MANUSCRIPT_REPLACEMENTS.md`, `09_values/FUTURE_WORK.md`

Numbers: only `experiment/results/oracles/manuscript_values.json`.
32-bit / Arancino: future work, after submission.

## Replace in the `.tex`

1. Entire abstract — medians 3,083.210 / 2,104.770; 100 PE; 9,000; 60 s / 120 s. Without “short-lived are crash”.
2. Every 31 / 3,100 / 155 / 17+14 / 10 s sentence.
3. Table 4 SkewMask: 11/30 vs 30/30. Delete 9/31.
4. Table 5: delete 155/155. Paste 60 s survival (letter, Table 2).
5. Table 7: delete −87.2 / −38.5. TMW_DO malicious persistent **+37,387 [26,146; 42,770]** (n=23). TMW_DM WS +0.451.
6. §VI: 120/60; NAT–EMPTY–TMW0; `sample_count>0` is **post hoc**.
7. §VIII: `FUTURE_WORK.md` (32-bit + Arancino bake-off afterwards).
8. Conclusion: no transparency, no “we beat Arancino”, no “the 100 used the 5 checks”.

Yellow on **every** changed sentence, including the abstract. Then a clean PDF.

## Do not mix

- IEEE 9000 campaign ≠ JCVHT.
- Oracles ≠ 100 PE corpus.
- Stage 5 (another DLL) ≠ 9000. Stage 7 (1800) does not rewrite the 9000.
