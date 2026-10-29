# Guest helpers

PowerShell/CMD used on the VM (`C:\TOMWare\scripts`). They write local dumps
under `Resultados/benchmarks/`.

Published tables are **not** here. They live in `experiment/results/`.

| Need | Use instead |
|------|-------------|
| 9 000-run host campaign | `experiment/scripts/host/Run-HostCampaign.ps1` |
| N=10 oracles | `experiment/validation/scripts/Run-Oracles.ps1` |
| TestRecoverWork + five Table-9 recaptures | `experiment/validation/scripts/Run-CtrlProgress.ps1` |

Keep these filenames: README examples and the guest still call `.\scripts\run-sample.ps1` and `.\scripts\r2-*.ps1`.
