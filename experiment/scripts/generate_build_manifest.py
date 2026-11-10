#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build-environment manifest and hashes of the experimental tools."""
import hashlib
import json
import platform
from pathlib import Path

repo_root = Path(__file__).resolve().parents[2]


def oracles_dir(root: Path) -> Path:
    for p in (root / "experiment" / "apps" / "oracles", root / "Resultados" / "Apps-Teste"):
        if p.is_dir():
            return p
    return root / "experiment" / "apps" / "oracles"


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
        "TestAntiDebug": get_hash(oracles_dir(repo_root) / "TestAntiDebug.exe"),
        "TestProcessEnum": get_hash(oracles_dir(repo_root) / "TestProcessEnum.exe"),
        "TestGetEnvironments": get_hash(oracles_dir(repo_root) / "TestGetEnvironments.exe"),
        "TestMemoryScan": get_hash(oracles_dir(repo_root) / "TestMemoryScan.exe"),
        "TestOverhead": get_hash(oracles_dir(repo_root) / "TestOverhead.exe"),
    }
}

out_path = repo_root / "experiment" / "environment" / "build_manifest.json"
out_path.parent.mkdir(parents=True, exist_ok=True)
with out_path.open("w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

print(f"Manifest written to: {out_path}")
