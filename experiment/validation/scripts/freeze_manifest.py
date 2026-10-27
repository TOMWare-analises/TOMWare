#!/usr/bin/env python3
"""Etapa 1: SHA-256 freeze of protocol, scripts, corpus, oracles, and 9000 raws."""
from __future__ import annotations

import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # TOMWare/
EXP = ROOT / "experiment"
OUT = EXP / "results" / "oracles"
SRC = ROOT / "TOMWare"


def sha256_file(path: Path, buf: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(buf)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def add_row(rows, path: Path, role: str, note: str = ""):
    if not path.exists():
        rows.append({
            "path": rel(path),
            "role": role,
            "exists": "false",
            "bytes": "",
            "sha256": "",
            "note": note or "missing",
        })
        return
    digest = sha256_file(path)
    rows.append({
        "path": rel(path),
        "role": role,
        "exists": "true",
        "bytes": path.stat().st_size,
        "sha256": digest,
        "note": note,
    })


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []

    protocol_files = [
        (EXP / "config" / "experiment.config.json", "protocol"),
        (EXP / "protocol" / "protocol.md", "protocol"),
        (EXP / "protocol" / "conditions.csv", "protocol"),
        (EXP / "protocol" / "oracle_conditions.csv", "protocol"),
        (EXP / "protocol" / "validity_rules.md", "protocol"),
        (EXP / "protocol" / "empty_tool_and_pin_probe.md", "protocol"),
        (EXP / "protocol" / "randomization_seeds.csv", "protocol"),
        (EXP / "schemas" / "run_record.schema.json", "protocol"),
        (EXP / "campaigns" / "corpus_aligned_10k" / "campaign.json", "campaign"),
        (EXP / "campaigns" / "corpus_aligned_10k" / "execution_plan.csv", "campaign"),
        (EXP / "corpus" / "corpus.csv", "corpus"),
        (EXP / "corpus" / "exclusions.csv", "corpus"),
        (EXP / "corpus" / "corpus.schema.md", "corpus"),
    ]
    runner_files = [
        EXP / "scripts" / "runner" / "Invoke-SingleRun.ps1",
        EXP / "scripts" / "runner" / "Run-Campaign.ps1",
        EXP / "scripts" / "host" / "Run-HostCampaign.ps1",
        EXP / "scripts" / "collectors" / "ProcessCollector.ps1",
        EXP / "scripts" / "planner" / "generate_plan.py",
        EXP / "scripts" / "validators" / "validate_campaign.py",
        EXP / "campaigns" / "corpus_aligned_10k" / "scripts" / "analyze_ieee_10k.py",
        EXP / "validation" / "scripts" / "Run-MatchedOracles.ps1",
    ]
    oracle_csvs = [
        OUT / "matched_timing_n30.csv",
        OUT / "matched_timing_summary.csv",
        OUT / "functional_oracles.csv",
        OUT / "native_oracles.csv",
        OUT / "module32_waits.csv",
        OUT / "module32_fixture.csv",
        OUT / "waits_n10.csv",
        OUT / "memcmp_n10.csv",
        OUT / "da_n10.csv",
        OUT / "identify_summary.csv",
        OUT / "build_id.json",
        OUT / "waits_clock_n10.csv",
        OUT / "memcmp_controls_n10.txt",
        OUT / "collector" / "resources.csv",
    ]

    for path, role in protocol_files:
        add_row(rows, path, role)
    for path in runner_files:
        add_row(rows, path, "script")
    for path in oracle_csvs:
        add_row(rows, path, "oracle_result")

    if SRC.is_dir():
        for path in sorted(SRC.glob("*.cpp")) + sorted(SRC.glob("*.h")):
            add_row(rows, path, "pintool_source")

    dll_host = ROOT / "x64" / "Release" / "TOMWare.dll"
    empty_host = ROOT / "x64" / "Release" / "EmptyPinTool.dll"
    add_row(rows, dll_host, "dll_host", "DLL no host; pode diferir da usada na VM")
    add_row(rows, empty_host, "dll_host", "EmptyPinTool no host; pode diferir da usada na VM")

    runs_dir = EXP / "campaigns" / "corpus_aligned_10k" / "raw" / "runs"
    run_files = sorted(runs_dir.glob("*.json")) if runs_dir.is_dir() else []
    raw_catalog = OUT / "raw_runs_sha256.csv"
    catalog_hasher = hashlib.sha256()
    if run_files:
        print(f"hashing {len(run_files)} raw JSON...", flush=True)
        with raw_catalog.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["path", "bytes", "sha256"])
            w.writeheader()
            for i, path in enumerate(run_files, 1):
                digest = sha256_file(path)
                size = path.stat().st_size
                w.writerow({"path": path.name, "bytes": size, "sha256": digest})
                catalog_hasher.update(f"{path.name} {size} {digest}\n".encode("ascii"))
                if i % 1000 == 0:
                    print(f"  {i}/{len(run_files)}", flush=True)
        add_row(rows, raw_catalog, "raw_catalog",
                f"{len(run_files)} JSON; merkle={catalog_hasher.hexdigest()}")
    else:
        add_row(
            rows,
            raw_catalog,
            "raw_catalog",
            "OMITTED on disk: campaign raw/runs JSON. Existing catalog kept; do not regenerate empty.",
        )

    # DLL hashes as recorded inside campaign JSON (guest copies)
    guest_hashes = {"tomware_sha256": set(), "empty_tool_sha256": set(), "pin_version": set()}
    if run_files:
        sample = json.loads(run_files[0].read_text(encoding="utf-8-sig"))
        ident = sample.get("identification", {})
        for key in guest_hashes:
            val = ident.get(key)
            if val:
                guest_hashes[key].add(str(val))
        # spot-check a few more
        for path in run_files[:: max(1, len(run_files) // 20)]:
            ident = json.loads(path.read_text(encoding="utf-8-sig")).get("identification", {})
            for key in guest_hashes:
                val = ident.get(key)
                if val:
                    guest_hashes[key].add(str(val))

    omitted = EXP / "results" / "oracles" / "omitted_files.csv"
    add_row(rows, omitted, "omitted_catalog", "Files kept off-repo or only on the guest/Downloads tree")

    manifest_path = OUT / "frozen_manifest.csv"
    with manifest_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["path", "role", "exists", "bytes", "sha256", "note"])
        w.writeheader()
        w.writerows(rows)

    meta = {
        "frozen_at_utc": datetime.now(timezone.utc).isoformat(),
        "n_manifest_rows": len(rows),
        "n_raw_json": len(run_files),
        "raw_merkle_sha256": catalog_hasher.hexdigest() if run_files else "not_recomputed_raws_omitted",
        "guest_tomware_sha256_values": sorted(guest_hashes["tomware_sha256"]),
        "guest_empty_tool_sha256_values": sorted(guest_hashes["empty_tool_sha256"]),
        "guest_pin_version_values": sorted(guest_hashes["pin_version"]),
        "host_tomware_dll_present": dll_host.exists(),
        "note": "Campaign DLL is the guest 4BBC6270 hash in build_id.json. Do not rebuild to tag. raw/runs omitted from disk.",
    }
    (OUT / "freeze_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(json.dumps(meta, indent=2))
    print("wrote", manifest_path)


if __name__ == "__main__":
    main()
