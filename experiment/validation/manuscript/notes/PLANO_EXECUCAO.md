# Execution plan — IEEE Access-2026-38745

Scope: IEEE Access only. Nothing goes to the reviewers before Stage 11.
No commit without authorization.

## Stage status

| Stage | Where | Status | Date |
|---|---|---|---|
| 0-6 | host/VM | **OK** | 22/10 |
| 7 Confirmation 1800 | VM | **OK** | 23/10 |
| 8 Arancino | host | **OK** (blocked) | 23/10 |
| 9 Values | host | **OK** | 23/10 |
| 10 Overleaf package + letters | host | **OK** | 23/10 |
| 11 Article PDF cross-check + submission | host | waiting on Overleaf | — |

## Stage 7 — OK

1800/1800. Collector 2.1.0. Integer exit in 1600 (88.9%). Null 200 (not crash).
`exception_crash` 891 by the <0 rule: 442 are `0xC0000135` (also on NAT);
AV `0xC0000005` = 105 (5.8%). Does not rewrite the 9000.
Report: `07_confirm/exitcode_report.md`.

## Stage 8 — OK (blocked)

No bake-off. Public Arancino is Pin 2.14 + VS2010 + 32-bit; the campaign is Pin 3.28 and 100 PE x64.
The 3.28 kit has `ia32\bin`; that does not unlock the x64 corpus nor compare generations.
Report: `08_arancino/BLOQUEIO.md`. No VM.

## Stage 9 — OK

`09_values/MANUSCRIPT_VALUES.json` + `VALUES.md`. Corpus: SHA-256 / source / x64 / profile only; family is a coarse label.
Future work 32-bit + Arancino: `09_values/FUTURE_WORK.md` (not run now).
Sends nothing. Overleaf PDF remains the 13/10 one.

## Stage 10 — OK

PDFs: `ieee_access_revision/Access-2026-38745_Overleaf_Instructions.pdf`,
`..._Response_to_Reviewers.pdf` (EN), `..._Resposta_aos_Revisores.pdf` (PT).
List: `10_overleaf/PACOTE.md`. Nothing to IEEE. No commit.

## Stage 11 — waiting on the new article PDF

When Overleaf exports: check against `09_values/MANUSCRIPT_VALUES.json`.
Only then authorization for commit and submission. 32-bit/Arancino after submission.
