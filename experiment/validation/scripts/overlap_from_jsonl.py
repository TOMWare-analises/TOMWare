#!/usr/bin/env python3
"""Intersect par_t1/par_t2 QPC intervals from session-2 jsonl (locale commas)."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "results_close"


def parse(path: Path) -> dict:
    rows = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line:
            continue
        line = re.sub(r'("observed_wait_ms":)(\d+),(\d+)', r"\1\2.\3", line)
        ev = json.loads(line)
        rows[ev["scenario"]] = ev
    return rows


def main() -> None:
    print("arm,rep,t1_ms,t2_ms,wall_ms,intersect_ms,union_ms,overlap_frac,start_gap_ms")
    for arm in ("NAT", "EMPTY", "TMW0", "DO"):
        inters = []
        fracs = []
        for i in range(1, 6):
            ev = parse(ROOT / f"ev_WAIT_{arm}_{i:02d}" / "events.jsonl")
            t1, t2, w = ev["par_t1"], ev["par_t2"], ev["par_wall"]
            a0, a1 = int(t1["start_reference_ns"]), int(t1["end_reference_ns"])
            b0, b1 = int(t2["start_reference_ns"]), int(t2["end_reference_ns"])
            inter = max(0, min(a1, b1) - max(a0, b0))
            union = max(a1, b1) - min(a0, b0)
            gap = abs(a0 - b0) / 1e6
            frac = inter / union if union else 0.0
            inters.append(inter / 1e6)
            fracs.append(frac)
            print(
                f"{arm},{i},{t1['observed_wait_ms']},{t2['observed_wait_ms']},"
                f"{w['observed_wait_ms']},{inter/1e6:.3f},{union/1e6:.3f},{frac:.3f},{gap:.3f}"
            )
        xs = sorted(inters)
        print(f"# {arm} intersect median_ms={(xs[2]):.3f}  min={xs[0]:.3f}  all_positive={all(x>0 for x in inters)}")


if __name__ == "__main__":
    main()
