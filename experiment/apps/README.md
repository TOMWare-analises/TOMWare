# Test applications (not published tables)

This folder used to live at the repository root as `Resultados/`. It is **not**
`experiment/results/` (that directory holds the paper CSVs/PDFs).

Guest snapshot `tomware_go` may still have `C:\TOMWare\Resultados\Apps-Teste`.
Scripts try `experiment\apps\oracles` first, then the legacy path.

| Path | What |
|------|------|
| `oracles/` | Pre-built oracles (`TestAntiDebug.exe`, `TestProcessEnum.exe`, `TestRecoverWork.exe`, …) |
| `oracles/Loop_X_1000/` | Same apps with 1 000 iterations |
| `src/` | Sources for those oracles |
| `screenshots/` | PoC screen captures |
| `evaluation/` | Local evaluation output (not paper tables) |
| `poc-logs/` | Early PoC tick logs |
| `local/` | VM dumps (`r2`, baseline JSON) — gitignored |

Paper tables: `../results/`.
