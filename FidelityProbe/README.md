# FidelityProbe

Pin tool for Reviewer 2 item 6 (behavioral fidelity):

- BBL count (coverage proxy)
- Image-load count
- Hit counts for a fixed Windows API watchlist (debugger/timing/file/memory/process)

## Build
```powershell
cd C:\TOMWare
.\scripts\r2-build-empty-pintool.ps1 -AlsoFidelityProbe
# output: x64\Release\FidelityProbe.dll
```

## Run (via driver)
```powershell
.\scripts\r2-behavioral-fidelity.ps1
```

Knob: `-o <path>` writes counters (`bbl_count`, `img_count`, `api_*`).
