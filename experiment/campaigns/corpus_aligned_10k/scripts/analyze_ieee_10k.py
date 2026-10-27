#!/usr/bin/env python3
"""Aggregate corpus_aligned_10k run records for the IEEE Access revision."""
from __future__ import annotations

import csv
import json
import math
import random
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "raw" / "runs"
CORPUS = ROOT.parents[1] / "corpus" / "corpus.csv"
OUT = ROOT / "processed"
OUT.mkdir(parents=True, exist_ok=True)

CONDS = ["NAT", "EMPTY", "TMW0", "TMW_DD", "TMW_DP", "TMW_DE", "TMW_DM", "TMW_DO", "TMW_ALL"]
CONTRASTS = [
    ("EMPTY", "NAT"),
    ("TMW0", "EMPTY"),
    ("TMW_DD", "TMW0"),
    ("TMW_DP", "TMW0"),
    ("TMW_DE", "TMW0"),
    ("TMW_DM", "TMW0"),
    ("TMW_DO", "TMW0"),
    ("TMW_ALL", "TMW0"),
    ("TMW_ALL", "NAT"),
]


def median(xs):
    xs = sorted(xs)
    n = len(xs)
    if n == 0:
        return None
    mid = n // 2
    return xs[mid] if n % 2 else 0.5 * (xs[mid - 1] + xs[mid])


def iqr(xs):
    xs = sorted(xs)
    n = len(xs)
    if n < 2:
        return None, None
    def pct(p):
        if n == 1:
            return xs[0]
        k = (n - 1) * p
        f = int(math.floor(k))
        c = min(f + 1, n - 1)
        return xs[f] + (xs[c] - xs[f]) * (k - f)
    return pct(0.25), pct(0.75)


def boot_ci(xs, nboot=2000, seed=705851366):
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


def wilson(k, n, z=1.96):
    if n <= 0:
        return None, None, None
    p = k / n
    den = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / den
    half = (z / den) * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return p, max(0.0, centre - half), min(1.0, centre + half)


def load_corpus():
    meta = {}
    with open(CORPUS, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            meta[row["sample_id"]] = row
    return meta


def outcome_class(oo):
    if not oo.get("launch_success"):
        return "launch_failed"
    if oo.get("timeout"):
        return "timeout"
    if oo.get("controlled_termination"):
        return "controlled_window"
    if oo.get("crash"):
        return "crash_exit"
    if oo.get("natural_completion"):
        return "natural_exit"
    if oo.get("still_active_at_window_end"):
        return "still_active"
    return "other"


def protocol_ok(profile, oo):
    if not oo.get("launch_success"):
        return False
    if profile == "persistent":
        return bool(oo.get("controlled_termination") or oo.get("still_active_at_window_end"))
    return bool(oo.get("natural_completion") or oo.get("timeout") or oo.get("crash"))


def load_runs(meta):
    rows = []
    for path in RUNS.glob("*.json"):
        rec = json.loads(path.read_text(encoding="utf-8-sig"))
        ident = rec["identification"]
        oo = rec["operational_outcome"]
        sid = ident["sample_id"]
        m = meta.get(sid, {})
        wall = ident.get("monotonic_duration_ms") or 0
        cpu = (rec.get("timing_and_cpu") or {}).get("cpu_total_ms") or 0
        ws = (rec.get("memory") or {}).get("peak_working_set_bytes") or 0
        priv = (rec.get("memory") or {}).get("peak_private_bytes") or 0
        threads = (rec.get("processes_threads_modules") or {}).get("peak_tracked_threads") or 0
        procs = (rec.get("processes_threads_modules") or {}).get("peak_tracked_processes") or 0
        samples = (rec.get("memory") or {}).get("sample_count") or 0
        missing = oo.get("missing_reason")
        rows.append({
            "run_id": ident["run_id"],
            "sample_id": sid,
            "group": m.get("group", ""),
            "profile": m.get("execution_profile", ""),
            "family": m.get("family_or_product", ""),
            "malware_type": m.get("malware_type", ""),
            "source": m.get("source", ""),
            "condition": ident["condition"],
            "repetition": ident["repetition"],
            "launch_success": bool(oo.get("launch_success")),
            "natural_completion": bool(oo.get("natural_completion")),
            "timeout": bool(oo.get("timeout")),
            "controlled_termination": bool(oo.get("controlled_termination")),
            "still_active": bool(oo.get("still_active_at_window_end")),
            "crash": bool(oo.get("crash")),
            "termination_reason": oo.get("termination_reason") or "",
            "missing_reason": missing or "",
            "outcome": outcome_class(oo),
            "protocol_ok": protocol_ok(m.get("execution_profile", ""), oo),
            "wall_ms": float(wall),
            "cpu_ms": float(cpu),
            "ws_mb": float(ws) / (1024 * 1024),
            "priv_mb": float(priv) / (1024 * 1024),
            "threads": int(threads or 0),
            "procs": int(procs or 0),
            "sample_count": int(samples or 0),
            "has_resources": int(samples or 0) > 0 and float(ws) > 0,
        })
    return rows


def wrow(path, fieldnames, data):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in data:
            w.writerow(r)


def main():
    meta = load_corpus()
    print("loading runs...", flush=True)
    rows = load_runs(meta)
    print(f"loaded {len(rows)}", flush=True)

    # completeness
    by_key = Counter((r["sample_id"], r["condition"], r["repetition"]) for r in rows)
    complete = sum(1 for v in by_key.values() if v == 1)
    host_closeout = sum(1 for r in rows if r["missing_reason"])
    summary = {
        "n_json": len(rows),
        "n_unique_triples": len(by_key),
        "n_expected": 100 * 9 * 10,
        "duplicate_or_missing": 100 * 9 * 10 - complete,
        "host_closeout_or_missing_reason": host_closeout,
        "conditions": dict(Counter(r["condition"] for r in rows)),
        "groups": dict(Counter(r["group"] for r in rows)),
        "profiles": dict(Counter(r["profile"] for r in rows)),
        "outcomes": dict(Counter(r["outcome"] for r in rows)),
    }
    (OUT / "completeness.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    # outcome table
    outcome_rows = []
    for group in ("benign", "malicious"):
        for profile in ("short_lived", "persistent"):
            for cond in CONDS:
                sub = [r for r in rows if r["group"] == group and r["profile"] == profile and r["condition"] == cond]
                n = len(sub)
                if n == 0:
                    continue
                c = Counter(r["outcome"] for r in sub)
                ok = sum(1 for r in sub if r["protocol_ok"])
                p, lo, hi = wilson(ok, n)
                outcome_rows.append({
                    "group": group, "profile": profile, "condition": cond, "n": n,
                    "protocol_ok": ok, "protocol_ok_rate": round(p, 4),
                    "wilson_lo": round(lo, 4), "wilson_hi": round(hi, 4),
                    "natural_exit": c.get("natural_exit", 0),
                    "crash_exit": c.get("crash_exit", 0),
                    "timeout": c.get("timeout", 0),
                    "controlled_window": c.get("controlled_window", 0),
                    "still_active": c.get("still_active", 0),
                    "launch_failed": c.get("launch_failed", 0),
                })
    wrow(OUT / "outcomes_by_stratum.csv", list(outcome_rows[0].keys()), outcome_rows)

    # per-sample medians
    buckets = defaultdict(list)
    for r in rows:
        buckets[(r["sample_id"], r["condition"])].append(r)

    sample_med = []
    for (sid, cond), rs in buckets.items():
        m0 = rs[0]
        walls = [x["wall_ms"] for x in rs]
        cpus = [x["cpu_ms"] for x in rs if x["has_resources"]]
        wss = [x["ws_mb"] for x in rs if x["has_resources"]]
        ths = [x["threads"] for x in rs if x["has_resources"]]
        ok = sum(1 for x in rs if x["protocol_ok"])
        sample_med.append({
            "sample_id": sid,
            "group": m0["group"],
            "profile": m0["profile"],
            "family": m0["family"],
            "condition": cond,
            "n_reps": len(rs),
            "n_ok": ok,
            "ok_rate": ok / len(rs),
            "med_wall_ms": median(walls),
            "med_cpu_ms": median(cpus),
            "med_ws_mb": median(wss),
            "med_threads": median(ths),
            "n_resource_reps": len(wss),
        })
    wrow(OUT / "sample_condition_medians.csv", list(sample_med[0].keys()), sample_med)

    # resource / wall aggregates
    agg = []
    for group in ("benign", "malicious"):
        for profile in ("short_lived", "persistent"):
            for cond in CONDS:
                sub = [s for s in sample_med if s["group"] == group and s["profile"] == profile and s["condition"] == cond]
                if not sub:
                    continue
                def pack(key, valid=lambda x: x is not None):
                    xs = [s[key] for s in sub if valid(s[key])]
                    q1, q3 = iqr(xs) if xs else (None, None)
                    lo, hi = boot_ci(xs) if xs else (None, None)
                    return xs, q1, q3, lo, hi
                walls, wq1, wq3, wlo, whi = pack("med_wall_ms")
                cpus, cq1, cq3, clo, chi = pack("med_cpu_ms")
                wss, sq1, sq3, slo, shi = pack("med_ws_mb")
                oks = [s["ok_rate"] for s in sub]
                agg.append({
                    "group": group, "profile": profile, "condition": cond,
                    "n_binaries": len(sub),
                    "median_ok_rate": round(median(oks), 4),
                    "median_wall_ms": None if not walls else round(median(walls), 1),
                    "wall_iqr_lo": None if wq1 is None else round(wq1, 1),
                    "wall_iqr_hi": None if wq3 is None else round(wq3, 1),
                    "wall_ci_lo": None if wlo is None else round(wlo, 1),
                    "wall_ci_hi": None if whi is None else round(whi, 1),
                    "median_cpu_ms": None if not cpus else round(median(cpus), 1),
                    "cpu_ci_lo": None if clo is None else round(clo, 1),
                    "cpu_ci_hi": None if chi is None else round(chi, 1),
                    "median_ws_mb": None if not wss else round(median(wss), 3),
                    "ws_ci_lo": None if slo is None else round(slo, 3),
                    "ws_ci_hi": None if shi is None else round(shi, 3),
                    "n_with_resources": sum(1 for s in sub if s["n_resource_reps"] > 0),
                })
    wrow(OUT / "stratum_medians.csv", list(agg[0].keys()), agg)

    # paired contrasts at binary level
    by_sc = {(s["sample_id"], s["condition"]): s for s in sample_med}
    contrast_rows = []
    for treat, base in CONTRASTS:
        for group in ("benign", "malicious"):
            for profile in ("short_lived", "persistent"):
                sids = sorted({s["sample_id"] for s in sample_med if s["group"] == group and s["profile"] == profile})
                d_wall, d_cpu, d_ws, d_ok = [], [], [], []
                for sid in sids:
                    a = by_sc.get((sid, treat))
                    b = by_sc.get((sid, base))
                    if not a or not b:
                        continue
                    if a["med_wall_ms"] is not None and b["med_wall_ms"] is not None:
                        d_wall.append(a["med_wall_ms"] - b["med_wall_ms"])
                    if a["med_cpu_ms"] is not None and b["med_cpu_ms"] is not None:
                        d_cpu.append(a["med_cpu_ms"] - b["med_cpu_ms"])
                    if a["med_ws_mb"] is not None and b["med_ws_mb"] is not None:
                        d_ws.append(a["med_ws_mb"] - b["med_ws_mb"])
                    d_ok.append(a["ok_rate"] - b["ok_rate"])
                def pack(xs):
                    if not xs:
                        return (None,) * 5
                    q1, q3 = iqr(xs)
                    lo, hi = boot_ci(xs)
                    return median(xs), q1, q3, lo, hi
                mw, w1, w3, wlo, whi = pack(d_wall)
                mc, c1, c3, clo, chi = pack(d_cpu)
                ms, s1, s3, slo, shi = pack(d_ws)
                mo, *_ = pack(d_ok)
                contrast_rows.append({
                    "contrast": f"{treat}-{base}",
                    "group": group, "profile": profile,
                    "n_binaries": len(sids),
                    "median_d_ok_rate": None if mo is None else round(mo, 4),
                    "median_d_wall_ms": None if mw is None else round(mw, 1),
                    "wall_ci_lo": None if wlo is None else round(wlo, 1),
                    "wall_ci_hi": None if whi is None else round(whi, 1),
                    "median_d_cpu_ms": None if mc is None else round(mc, 1),
                    "cpu_ci_lo": None if clo is None else round(clo, 1),
                    "cpu_ci_hi": None if chi is None else round(chi, 1),
                    "median_d_ws_mb": None if ms is None else round(ms, 3),
                    "ws_ci_lo": None if slo is None else round(slo, 3),
                    "ws_ci_hi": None if shi is None else round(shi, 3),
                })
    wrow(OUT / "paired_contrasts.csv", list(contrast_rows[0].keys()), contrast_rows)

    # overall protocol-ok (run level)
    overall = []
    for cond in CONDS:
        sub = [r for r in rows if r["condition"] == cond]
        ok = sum(1 for r in sub if r["protocol_ok"])
        p, lo, hi = wilson(ok, len(sub))
        overall.append({
            "condition": cond, "n": len(sub), "ok": ok,
            "rate": round(p, 4), "wilson_lo": round(lo, 4), "wilson_hi": round(hi, 4),
        })
    wrow(OUT / "overall_protocol_ok.csv", list(overall[0].keys()), overall)

    print(json.dumps(summary, indent=2))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
