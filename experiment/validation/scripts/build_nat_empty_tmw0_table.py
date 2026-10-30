#!/usr/bin/env python3
"""Consolidated NAT / EMPTY / TMW0 table from corpus_aligned_10k medians.

Does not rerun the 9,000. Bootstrap 2,000, seed 705851366, same estimator as
analyze_ieee_10k.py. Duration medians are median-of-per-binary-medians.
Paired deltas are median of (A - B) within each binary.
"""
from __future__ import annotations

import csv
import math
import random
from collections import defaultdict
from pathlib import Path

SEED = 705851366
NBOOT = 2000
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "results" / "campaign" / "corpus_aligned_10k" / "sample_condition_medians.csv"
OUT = ROOT / "results" / "campaign" / "corpus_aligned_10k" / "nat_empty_tmw0_table.csv"
MD = ROOT / "validation" / "manuscript" / "ieee_access_ressubmissao" / "TABELA_NAT_EMPTY_TMW0.md"

CONDS = ("NAT", "EMPTY", "TMW0")
PAIRS = (("EMPTY", "NAT"), ("TMW0", "NAT"), ("TMW0", "EMPTY"))


def median(xs):
    xs = sorted(xs)
    n = len(xs)
    if n == 0:
        return None
    mid = n // 2
    return xs[mid] if n % 2 else 0.5 * (xs[mid - 1] + xs[mid])


def boot_ci(xs, nboot=NBOOT, seed=SEED):
    xs = [x for x in xs if x is not None]
    if len(xs) < 2:
        return None, None
    rng = random.Random(seed)
    meds = []
    n = len(xs)
    for _ in range(nboot):
        sample = [xs[rng.randrange(n)] for _ in range(n)]
        meds.append(median(sample))
    meds.sort()
    lo = meds[int(0.025 * nboot)]
    hi = meds[min(nboot - 1, int(0.975 * nboot))]
    return lo, hi


def num(x):
    if x is None or x == "":
        return None
    try:
        v = float(x)
    except ValueError:
        return None
    if math.isnan(v) or math.isinf(v):
        return None
    return v


def r(v, nd=3):
    if v is None:
        return ""
    return round(v, nd)


def main() -> None:
    rows = []
    with SRC.open(encoding="utf-8", newline="") as f:
        for rec in csv.DictReader(f):
            if rec["condition"] not in CONDS:
                continue
            rec["med_wall_ms"] = num(rec["med_wall_ms"])
            rec["med_cpu_ms"] = num(rec["med_cpu_ms"])
            rec["med_ws_mb"] = num(rec["med_ws_mb"])
            rec["n_resource_reps"] = int(float(rec["n_resource_reps"] or 0))
            rows.append(rec)

    by = defaultdict(list)
    for rec in rows:
        by[(rec["group"], rec["profile"])].append(rec)

    by_sc = {(rec["sample_id"], rec["condition"]): rec for rec in rows}
    out_rows = []
    for group in ("benign", "malicious"):
        for profile in ("short_lived", "persistent"):
            key = (group, profile)
            sub = by[key]
            sids = sorted({r["sample_id"] for r in sub})
            n_bin = len(sids)
            levels = {}
            for cond in CONDS:
                cs = [r for r in sub if r["condition"] == cond]
                walls = [r["med_wall_ms"] for r in cs if r["med_wall_ms"] is not None]
                cpus = [r["med_cpu_ms"] for r in cs if r["med_cpu_ms"] is not None]
                wss = [r["med_ws_mb"] for r in cs if r["med_ws_mb"] is not None]
                wlo, whi = boot_ci(walls) if walls else (None, None)
                clo, chi = boot_ci(cpus) if cpus else (None, None)
                slo, shi = boot_ci(wss) if wss else (None, None)
                levels[cond] = {
                    "n_wall": len(walls),
                    "n_cpu": len(cpus),
                    "n_ws": len(wss),
                    "n_missing_wall": n_bin - len(walls),
                    "n_missing_cpu": n_bin - len(cpus),
                    "n_missing_ws": n_bin - len(wss),
                    "median_wall_s": None if not walls else median(walls) / 1000.0,
                    "wall_ci_lo_s": None if wlo is None else wlo / 1000.0,
                    "wall_ci_hi_s": None if whi is None else whi / 1000.0,
                    "median_cpu_s": None if not cpus else median(cpus) / 1000.0,
                    "cpu_ci_lo_s": None if clo is None else clo / 1000.0,
                    "cpu_ci_hi_s": None if chi is None else chi / 1000.0,
                    "median_ws_mb": None if not wss else median(wss),
                    "ws_ci_lo_mb": slo,
                    "ws_ci_hi_mb": shi,
                }

            pair_pack = {}
            for treat, base in PAIRS:
                d_wall, d_cpu, d_ws = [], [], []
                n_pair_wall = n_pair_cpu = n_pair_ws = 0
                for sid in sids:
                    a = by_sc.get((sid, treat))
                    b = by_sc.get((sid, base))
                    if not a or not b:
                        continue
                    if a["med_wall_ms"] is not None and b["med_wall_ms"] is not None:
                        d_wall.append(a["med_wall_ms"] - b["med_wall_ms"])
                        n_pair_wall += 1
                    if a["med_cpu_ms"] is not None and b["med_cpu_ms"] is not None:
                        d_cpu.append(a["med_cpu_ms"] - b["med_cpu_ms"])
                        n_pair_cpu += 1
                    if a["med_ws_mb"] is not None and b["med_ws_mb"] is not None:
                        d_ws.append(a["med_ws_mb"] - b["med_ws_mb"])
                        n_pair_ws += 1
                tag = f"{treat}_minus_{base}"
                wlo, whi = boot_ci(d_wall) if d_wall else (None, None)
                clo, chi = boot_ci(d_cpu) if d_cpu else (None, None)
                slo, shi = boot_ci(d_ws) if d_ws else (None, None)
                pair_pack[tag] = {
                    "n_pair_wall": n_pair_wall,
                    "n_pair_cpu": n_pair_cpu,
                    "n_pair_ws": n_pair_ws,
                    "n_missing_wall_pairs": n_bin - n_pair_wall,
                    "n_missing_cpu_pairs": n_bin - n_pair_cpu,
                    "n_missing_ws_pairs": n_bin - n_pair_ws,
                    "median_d_wall_s": None if not d_wall else median(d_wall) / 1000.0,
                    "d_wall_ci_lo_s": None if wlo is None else wlo / 1000.0,
                    "d_wall_ci_hi_s": None if whi is None else whi / 1000.0,
                    "median_d_cpu_s": None if not d_cpu else median(d_cpu) / 1000.0,
                    "d_cpu_ci_lo_s": None if clo is None else clo / 1000.0,
                    "d_cpu_ci_hi_s": None if chi is None else chi / 1000.0,
                    "median_d_ws_mb": None if not d_ws else median(d_ws),
                    "d_ws_ci_lo_mb": slo,
                    "d_ws_ci_hi_mb": shi,
                }

            row = {
                "group": group,
                "profile": profile,
                "n_binaries": n_bin,
                "estimator": "median_of_per_binary_medians",
                "bootstrap_n": NBOOT,
                "bootstrap_seed": SEED,
                "cpu_note": "recorded zero is descriptive; not an efficiency claim",
            }
            for cond in CONDS:
                for k, v in levels[cond].items():
                    row[f"{cond}_{k}"] = r(v, 4) if isinstance(v, float) else v
            for treat, base in PAIRS:
                tag = f"{treat}_minus_{base}"
                for k, v in pair_pack[tag].items():
                    row[f"{tag}_{k}"] = r(v, 4) if isinstance(v, float) else v
            out_rows.append(row)

    fieldnames = list(out_rows[0].keys())
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(out_rows)

    lines = [
        "# NAT / EMPTY / TMW0 consolidated table",
        "",
        f"Source: `{SRC.as_posix()}`. Not a rerun of the 9,000. Bootstrap {NBOOT}, seed {SEED}.",
        "Duration = median of per-binary medians. Paired delta = median of (A − B) within each binary.",
        "CPU zeros are descriptive. NAT working-set/CPU cells are often empty (native collector).",
        "",
        "| class | profile | n | NAT s | EMPTY s | TMW0 s | EMPTY−NAT s [CI] | TMW0−NAT s [CI] | TMW0−EMPTY s [CI] | NAT CPU n missing | NAT WS n missing |",
        "|---|---|---:|---:|---:|---:|---|---|---|---:|---:|",
    ]
    for row in out_rows:
        def cell(cond):
            v = row[f"{cond}_median_wall_s"]
            lo = row[f"{cond}_wall_ci_lo_s"]
            hi = row[f"{cond}_wall_ci_hi_s"]
            return f"{v} [{lo}, {hi}]"

        def dcell(tag):
            v = row[f"{tag}_median_d_wall_s"]
            lo = row[f"{tag}_d_wall_ci_lo_s"]
            hi = row[f"{tag}_d_wall_ci_hi_s"]
            nmiss = row[f"{tag}_n_missing_wall_pairs"]
            return f"{v} [{lo}, {hi}] (miss {nmiss})"

        lines.append(
            "| {g} | {p} | {n} | {nat} | {emp} | {tmw} | {en} | {tn} | {te} | {mc} | {mw} |".format(
                g=row["group"],
                p=row["profile"],
                n=row["n_binaries"],
                nat=cell("NAT"),
                emp=cell("EMPTY"),
                tmw=cell("TMW0"),
                en=dcell("EMPTY_minus_NAT"),
                tn=dcell("TMW0_minus_NAT"),
                te=dcell("TMW0_minus_EMPTY"),
                mc=row["NAT_n_missing_cpu"],
                mw=row["NAT_n_missing_ws"],
            )
        )
    lines.append("")
    lines.append(
        "Check (benign short-lived): NAT 0.260 s, EMPTY 1.485 s, TMW0 1.973 s "
        "from stratum medians 260.0 / 1484.8 / 1973.5 ms, n=25."
    )
    MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("WROTE", OUT)
    print("WROTE", MD)
    for row in out_rows:
        if row["group"] == "benign" and row["profile"] == "short_lived":
            print(
                "CHECK",
                "NAT", row["NAT_median_wall_s"],
                "EMPTY", row["EMPTY_median_wall_s"],
                "TMW0", row["TMW0_median_wall_s"],
            )


if __name__ == "__main__":
    main()
