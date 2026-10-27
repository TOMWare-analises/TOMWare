#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gera manifesto do ambiente de build e hashes das ferramentas experimentais."""
import hashlib
import json
import platform
from pathlib import Path

repo_root = Path(__file__).resolve().parents[2]

def get_hash(p: Path) -> str:
    if not p.exists():
        return "missing"
    return hashlib.sha256(p.read_bytes()).hexdigest().lower()

manifest = {
    "schema_version": 1,
    "environment": {
        "host_os": platform.system(),
        "host_release": platform.release(),
        "host_version": platform.version(),
        "host_machine": platform.machine(),
        "python_version": platform.python_version(),
    },
    "tools": {
        "pin_exe": {
            "path": "pin/pin.exe",
            "sha256": get_hash(repo_root / "pin" / "pin.exe")
        },
        "tomware_dll": {
            "path": "x64/Release/TOMWare.dll",
            "sha256": get_hash(repo_root / "x64" / "Release" / "TOMWare.dll")
        },
        "empty_tool_dll": {
            "path": "x64/Release/EmptyPinTool.dll",
            "sha256": get_hash(repo_root / "x64" / "Release" / "EmptyPinTool.dll")
        },
        "fidelity_probe_dll": {
            "path": "x64/Release/FidelityProbe.dll",
            "sha256": get_hash(repo_root / "x64" / "Release" / "FidelityProbe.dll")
        }
    },
    "oracles": {
        "TestAntiDebug": get_hash(repo_root / "Resultados" / "Apps-Teste" / "TestAntiDebug.exe"),
        "TestProcessEnum": get_hash(repo_root / "Resultados" / "Apps-Teste" / "TestProcessEnum.exe"),
        "TestGetEnvironments": get_hash(repo_root / "Resultados" / "Apps-Teste" / "TestGetEnvironments.exe"),
        "TestMemoryScan": get_hash(repo_root / "Resultados" / "Apps-Teste" / "TestMemoryScan.exe"),
        "TestOverhead": get_hash(repo_root / "Resultados" / "Apps-Teste" / "TestOverhead.exe"),
    }
}

out_path = repo_root / "experiment" / "environment" / "build_manifest.json"
out_path.parent.mkdir(parents=True, exist_ok=True)
with out_path.open("w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

print(f"Manifesto gerado em: {out_path}")
