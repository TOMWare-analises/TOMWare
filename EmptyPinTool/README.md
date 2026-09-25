# EmptyPinTool

Minimal noop Pintool for Reviewer 2 baseline ladder level `pin_empty_tool`.

## Build (VM)
```powershell
cd C:\TOMWare
.\scripts\r2-build-empty-pintool.ps1
# output: x64\Release\EmptyPinTool.dll
```

Or Visual Studio: open `TOMWare.sln` → build **EmptyPinTool** | Release | x64.

## Purpose
Pin + instrumentation runtime **without** TOMWare defensive modules, so the ladder can
separate Pin overhead from TOMWare module effects.
