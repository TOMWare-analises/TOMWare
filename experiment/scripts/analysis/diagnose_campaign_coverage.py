#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Diagnóstico de cobertura real vs. registros JSON da campanha."""
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8-sig") as f:
        return json.load(f)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--campaign-dir", required=True)
    parser.add_argument("--corpus-csv", required=True)
    args = parser.parse_args()

    campaign_dir = Path(args.campaign_dir)
    manifest = load_json(campaign_dir / "campaign.json")
    runs_dir = campaign_dir / "raw" / "runs"
    processed_dir = campaign_dir / "processed"
    processed_dir.mkdir(parents=True, exist_ok=True)

    campaign_hashes = {s["sample_id"]: s["sha256"].lower() for s in manifest["samples"]}
    corpus_hashes = {}
    with Path(args.corpus_csv).open("r", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            corpus_hashes[row["sample_id"]] = row["sha256"].lower()

    campaign_set = set(campaign_hashes.values())
    corpus_set = set(corpus_hashes.values())
    overlap = campaign_set & corpus_set
    id_mismatch = [
        sid
        for sid, h in campaign_hashes.items()
        if corpus_hashes.get(sid) and corpus_hashes[sid] != h
    ]

    records = []
    for p in runs_dir.glob("*.json"):
        try:
            records.append(load_json(p))
        except Exception as exc:
            print(f"JSON inválido: {p.name}: {exc}")

    term = Counter()
    missing = Counter()
    launch_ok = 0
    by_sample = defaultdict(lambda: {"ok": 0, "fail": 0, "reasons": Counter(), "cpu_nonzero": 0, "ws_nonzero": 0})
    term_ok = Counter()

    for r in records:
        ident = r.get("identification", {})
        out = r.get("operational_outcome", {})
        timing = r.get("timing_and_cpu", {})
        mem = r.get("memory", {})
        sid = ident.get("sample_id", "?")
        reason = out.get("termination_reason") or "unknown"
        miss = out.get("missing_reason") or ""
        term[reason] += 1
        if miss:
            missing[miss] += 1
        ok = bool(out.get("launch_success"))
        if ok:
            launch_ok += 1
            by_sample[sid]["ok"] += 1
            term_ok[reason] += 1
            if (timing.get("cpu_total_ms") or 0) > 0:
                by_sample[sid]["cpu_nonzero"] += 1
            if (mem.get("peak_working_set_bytes") or 0) > 0:
                by_sample[sid]["ws_nonzero"] += 1
        else:
            by_sample[sid]["fail"] += 1
        by_sample[sid]["reasons"][reason] += 1

    successful_samples = sorted([s for s, d in by_sample.items() if d["ok"] > 0])
    failed_only = sorted([s for s, d in by_sample.items() if d["ok"] == 0])

    report = {
        "campaign_id": manifest.get("campaign_id"),
        "json_records_on_disk": len(records),
        "planned_runs": manifest.get("total_planned_runs"),
        "launch_success_count": launch_ok,
        "launch_failed_count": len(records) - launch_ok,
        "launch_success_pct": round(100.0 * launch_ok / max(len(records), 1), 2),
        "binaries_that_launched": successful_samples,
        "binaries_that_never_launched_count": len(failed_only),
        "termination_reason_all": dict(term),
        "termination_reason_launch_success_only": dict(term_ok),
        "missing_reason": dict(missing),
        "corpus_vs_campaign": {
            "campaign_unique_hashes": len(campaign_set),
            "corpus_csv_unique_hashes": len(corpus_set),
            "hash_overlap_count": len(overlap),
            "sample_id_hash_mismatches": len(id_mismatch),
            "note": (
                "O runner procura o ficheiro pelo SHA256 do execution_plan/campaign.json, "
                "não pelo corpus.csv atual. Overlap baixo explica file_not_found em massa."
            ),
        },
        "successful_sample_detail": {
            sid: {
                "ok": by_sample[sid]["ok"],
                "fail": by_sample[sid]["fail"],
                "cpu_nonzero": by_sample[sid]["cpu_nonzero"],
                "ws_nonzero": by_sample[sid]["ws_nonzero"],
                "campaign_sha256": campaign_hashes.get(sid),
                "corpus_csv_sha256": corpus_hashes.get(sid),
                "reasons": dict(by_sample[sid]["reasons"]),
            }
            for sid in successful_samples
        },
        "scientific_validity": "invalid_for_publication",
        "reason": (
            "A esmagadora maioria das corridas não executou o binário "
            "(launch_failed/file_not_found). Tabelas de overhead não são interpretáveis."
        ),
    }

    out_path = processed_dir / "coverage_diagnosis.json"
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(json.dumps(report, indent=2, ensure_ascii=False))
    print(f"\nGravado: {out_path}")


if __name__ == "__main__":
    main()
