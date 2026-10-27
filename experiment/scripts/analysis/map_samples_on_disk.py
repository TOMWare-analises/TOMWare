#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Inventaria TOMWare/samples e cruza com corpus.csv (apenas nomes/tamanhos/hashes do nome)."""
from __future__ import annotations

import csv
import json
import re
from pathlib import Path

REPO = Path(r"D:\MMB\workspace\tomware-melhorias\TOMWare")
SAMPLES = REPO / "samples"
CORPUS = REPO / "experiment" / "corpus" / "corpus.csv"
OUT = REPO / "experiment" / "corpus" / "samples_disk_inventory.json"

SHA_RE = re.compile(r"^[0-9a-fA-F]{64}$")


def list_files(folder: Path) -> list[dict]:
    if not folder.exists():
        return []
    rows = []
    for p in sorted(folder.iterdir()):
        if not p.is_file():
            continue
        stem = p.stem
        rows.append({
            "name": p.name,
            "stem": stem,
            "ext": p.suffix.lower(),
            "size_bytes": p.stat().st_size,
            "stem_is_sha256": bool(SHA_RE.match(stem)),
            "sha256_from_name": stem.lower() if SHA_RE.match(stem) else "",
        })
    return rows


def main() -> None:
    benign_dir = SAMPLES / "benign"
    infected_dir = SAMPLES / "infected"
    other_dirs = []
    if SAMPLES.exists():
        other_dirs = [p.name for p in SAMPLES.iterdir() if p.is_dir()]

    benign = list_files(benign_dir)
    infected = list_files(infected_dir)
    infected_nested = []
    if infected_dir.exists():
        for p in infected_dir.rglob("*"):
            if p.is_file() and p.parent != infected_dir:
                infected_nested.append(str(p.relative_to(SAMPLES)))

    corpus = []
    if CORPUS.exists():
        with CORPUS.open("r", encoding="utf-8-sig") as f:
            corpus = list(csv.DictReader(f))

    ben_on_disk = {r["sha256_from_name"] for r in benign if r["sha256_from_name"]}
    inf_on_disk = {r["sha256_from_name"] for r in infected if r["sha256_from_name"]}
    disk_all = ben_on_disk | inf_on_disk

    corpus_ben = [r for r in corpus if r.get("group") == "benign"]
    corpus_mal = [r for r in corpus if r.get("group") == "malicious"]
    corpus_ben_sha = {r["sha256"].lower() for r in corpus_ben}
    corpus_mal_sha = {r["sha256"].lower() for r in corpus_mal}

    report = {
        "samples_root": str(SAMPLES),
        "samples_root_exists": SAMPLES.exists(),
        "subdirs": other_dirs,
        "benign_dir_exists": benign_dir.exists(),
        "infected_dir_exists": infected_dir.exists(),
        "benign_file_count": len(benign),
        "infected_file_count": len(infected),
        "benign_exe_sha_named": len([r for r in benign if r["ext"] == ".exe" and r["stem_is_sha256"]]),
        "infected_zip_sha_named": len([r for r in infected if r["ext"] == ".zip" and r["stem_is_sha256"]]),
        "infected_exe_sha_named": len([r for r in infected if r["ext"] == ".exe" and r["stem_is_sha256"]]),
        "infected_other_ext": sorted({r["ext"] for r in infected}),
        "infected_nested_files": infected_nested[:50],
        "corpus_rows": len(corpus),
        "corpus_benign_present_on_disk": sorted(corpus_ben_sha & ben_on_disk),
        "corpus_benign_missing_on_disk": sorted(corpus_ben_sha - ben_on_disk),
        "corpus_malicious_present_on_disk": sorted(corpus_mal_sha & inf_on_disk),
        "corpus_malicious_missing_on_disk": sorted(corpus_mal_sha - inf_on_disk),
        "disk_benign_not_in_corpus": sorted(ben_on_disk - corpus_ben_sha),
        "disk_infected_not_in_corpus": sorted(inf_on_disk - corpus_mal_sha),
        "benign_files": benign,
        "infected_files": infected,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k not in ("benign_files", "infected_files")}, indent=2))
    print(f"WROTE {OUT}")


if __name__ == "__main__":
    main()
