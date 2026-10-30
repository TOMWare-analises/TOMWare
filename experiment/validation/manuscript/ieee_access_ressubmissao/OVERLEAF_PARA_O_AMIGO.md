# Overleaf — Access-2026-38745 (collaborator only, not IEEE)

The repository does **not** contain the IEEE Access `.tex` that produced the 22-page PDF. The English base is `Access-2026-38745_REVISION_BASE.pdf` (SHA-256 `CFD80F0D0EE9…`, 22 pages). It is already in English. Do **not** restore Portuguese evaluation pages from the withdrawn `5CBC` file. Portuguese-excerpt instructions are outdated.

Integral compiled views in this pack:

- `Access-2026-38745_REVISION.pdf` — 22-page CFD80 base + clean Tables 21–27 addendum
- `Access-2026-38745_REVISION_HL.pdf` — same, yellow on new or replacement sentences
- `Access-2026-38745_REVISION_TABLES.tex` — LaTeX for Tables 21–27 (existing Tables 1–20 unshifted)

## Paste, in this order

1. `INSERCOES_FINAIS_EN.md` — delete the four English denials in V-B, V-D, VI-C, and VII-A; insert Tables 21–27; NAT/EMPTY/TMW0; Pin-without-tool stdout/stderr/exit; 6,517; manifesto; R4.3.
2. `Access-2026-38745_REVISION_TABLES.tex` — LaTeX tables.
3. `CARTA_FINAL_EN.md` — official point-by-point letter. Full answer for every reviewer. Do not write “Same as R1.1”.
4. `FRASES_PROIBIDAS.txt`
5. `REPRODUCIBILITY.txt` — the single git commit.

Withdrawn (do not paste): `PATCH_VB_VIC_VIIA_EN.md` Portuguese-excerpt block, `INSERCOES_EN.md`, `CARTA_PONTO_A_PONTO_EN.md`, `MATRIZ_SEIS_REVISORES.csv`, `RELATORIO_SEIS_REVISORES.md`.

## Highlight pass

Mark **every changed sentence** in yellow (`\hl`), including the abstract if touched. Then export a clean PDF without `\hl`.

## Do not mix

Access = 100 PE / 9,000 / 60–120 s.  
JCVHT = 31 PE / 3,100 / 10 s.  
CTRL_PE / TestRecoverWork / wait 4/10 stay out of Access tables.

## Resource filter

`sample_count>0` is **post hoc**. Duration pairs = 98. SanitizePinEnvVars CPU/memory = 97 (BEN_32). Do not write that the filter was in `experiment.config.json` before the campaign.

## Remaining experimental gaps (keep as partial)

API traces and coverage; per-binary hook counters; full temporal coherence; malware check–branch–recovered-behavior case; Arancino / COBAI / Peekaboo bake-off.
