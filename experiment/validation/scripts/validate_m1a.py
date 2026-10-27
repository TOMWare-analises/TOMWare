#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Freeze M1a numbers. Oracle C++ uses score > 3000 as anomaly (OK is <=)."""
from __future__ import annotations

import csv
import hashlib
from pathlib import Path

SRC = Path(__file__).resolve().parent / "results" / "matched_timing_n30.csv"


def dec(s: str) -> float:
    return float(str(s).replace(",", ".").strip())


def conv_median(xs: list[float]) -> float:
    xs = sorted(xs)
    n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2


def main() -> None:
    rows = list(csv.DictReader(SRC.open(encoding="utf-8-sig")))
    h = hashlib.sha256(SRC.read_bytes()).hexdigest()
    print("file", SRC)
    print("sha256", h)
    print("n_rows", len(rows), "(expect 90)")
    print("oracle_operator: TestOverhead anomaly if score > 3000; OK if score <= 3000")
    by = {}
    for r in rows:
        by.setdefault(r["arm"], []).append(dec(r["ticks"]))
    for arm in ("TMW0", "GO", "GO_DO"):
        vals = by[arm]
        med = conv_median(vals)
        lt = sum(1 for v in vals if v < 3000)
        le = sum(1 for v in vals if v <= 3000)
        eq = sum(1 for v in vals if v == 3000)
        print(
            f"{arm}: n={len(vals)} median={med:.3f} min={min(vals):.2f} max={max(vals):.2f} "
            f"lt3000={lt} le3000={le} eq3000={eq}"
        )
        if lt != le:
            print("  NOTE: < vs <= would differ")


if __name__ == "__main__":
    main()
