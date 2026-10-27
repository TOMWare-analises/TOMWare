#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Etapa 2: audit 9000 raw JSON without modifying them.

Reclassifies collector-artifact 'exception_crash' (exit_code null, exception_code '0x')
as exited_before_limit_exit_code_unknown. Reports effective n per metric.
sample_count > 0 is treated as a POST-HOC resource-validity filter, not a priori.
"""
from __future__ import annotations

import csv
import json
import math
import random
from collections import Counter, defaultdict
from pathlib import Path

CAMP = Path(__file__).resolve().parents[2] / "campaigns" / "corpus_aligned_10k"
RUNS = CAMP / "raw" / "runs"
CORPUS = Path(__file__).resolve().parents[2] / "corpus" / "corpus.csv"
OUT = Path(__file__).resolve().parents[2] / "results" / "oracles" / "audit"
SEED = 705851366
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
        k = (n - 1) * p
        f = int(math.floor(k))
        c = min(f + 1, n - 1)
        return xs[f] + (xs[c] - xs[f]) * (k - f)

    return pct(0.25), pct(0.75)


def boot_ci(xs, nboot=2000, seed=SEED):
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
    return meds[int(0.025 * nboot)], meds[min(nboot - 1, int(0.975 * nboot))]


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
    with open(CORPUS, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            meta[row["sample_id"]] = row
    return meta


def audit_outcome(oo):
    """Reclassify without changing the raw JSON."""
    raw_reason = oo.get("termination_reason") or ""
    exit_code = oo.get("exit_code")
    exc = (oo.get("exception_code") or "").strip()
    crash_flag = bool(oo.get("crash"))

    if not oo.get("launch_success"):
        audited = "launch_failed"
    elif oo.get("timeout"):
        audited = "timeout_expired"
    elif oo.get("controlled_termination") or oo.get("still_active_at_window_end"):
        audited = "window_controlled_termination"
    elif crash_flag and exit_code is None and exc in ("", "0x", "0X"):
        audited = "exited_before_limit_exit_code_unknown"
    elif crash_flag:
        audited = "exception_crash"
    elif oo.get("natural_completion"):
        audited = "natural_exit"
    else:
        audited = "other"

    return audited, raw_reason, exit_code, exc


def protocol_recorded(profile, audited, launch_ok):
    if not launch_ok:
        return False
    if profile == "persistent":
        return audited == "window_controlled_termination"
    return audited in (
        "exited_before_limit_exit_code_unknown",
        "timeout_expired",
        "natural_exit",
        "exception_crash",
    )


def load_runs(meta):
    rows = []
    for path in RUNS.glob("*.json"):
        rec = json.loads(path.read_text(encoding="utf-8-sig"))
        ident = rec["identification"]
        oo = rec["operational_outcome"]
        sid = ident["sample_id"]
        m = meta.get(sid, {})
        audited, raw_reason, exit_code, exc = audit_outcome(oo)
        wall = ident.get("monotonic_duration_ms") or 0
        mem = rec.get("memory") or {}
        cpu = (rec.get("timing_and_cpu") or {}).get("cpu_total_ms") or 0
        ws = mem.get("peak_working_set_bytes") or 0
        samples = mem.get("sample_count") or 0
        profile = m.get("execution_profile", "")
        launch_ok = bool(oo.get("launch_success"))
        has_resources = int(samples or 0) > 0 and float(ws) > 0
        rows.append({
            "run_id": ident["run_id"],
            "sample_id": sid,
            "sha256": ident.get("sha256") or m.get("sha256", ""),
            "group": m.get("group", ""),
            "profile": profile,
            "condition": ident["condition"],
            "repetition": ident["repetition"],
            "launch_success": launch_ok,
            "raw_termination_reason": raw_reason,
            "raw_crash_flag": bool(oo.get("crash")),
            "exit_code": "" if exit_code is None else exit_code,
            "exception_code": exc,
            "audited_outcome": audited,
            "protocol_recorded": protocol_recorded(profile, audited, launch_ok),
            "wall_ms": float(wall),
            "cpu_ms": float(cpu),
            "ws_mb": float(ws) / (1024 * 1024),
            "sample_count": int(samples or 0),
            "has_resources": has_resources,
            "resource_rule": "post_hoc_sample_count_gt_0",
            "tomware_sha256": ident.get("tomware_sha256") or "",
            "pin_version": ident.get("pin_version") or "",
        })
    return rows


def wrow(path, fieldnames, data):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in data:
            w.writerow(r)


def r4(x):
    return None if x is None else round(x, 4)


def r1(x):
    return None if x is None else round(x, 1)


def r3(x):
    return None if x is None else round(x, 3)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    meta = load_corpus()
    print("loading runs...", flush=True)
    rows = load_runs(meta)
    print(f"loaded {len(rows)}", flush=True)

    run_fields = [
        "run_id", "sample_id", "sha256", "group", "profile", "condition", "repetition",
        "launch_success", "raw_termination_reason", "raw_crash_flag", "exit_code",
        "exception_code", "audited_outcome", "protocol_recorded", "wall_ms", "cpu_ms",
        "ws_mb", "sample_count", "has_resources", "resource_rule", "tomware_sha256",
        "pin_version",
    ]
    wrow(OUT / "run_level_audited.csv", run_fields, rows)

    by_key = Counter((r["sample_id"], r["condition"], r["repetition"]) for r in rows)
    summary = {
        "n_json": len(rows),
        "n_unique_triples": len(by_key),
        "n_expected": 9000,
        "duplicate_or_missing": 9000 - sum(1 for v in by_key.values() if v == 1),
        "raw_termination_reason": dict(Counter(r["raw_termination_reason"] for r in rows)),
        "audited_outcome": dict(Counter(r["audited_outcome"] for r in rows)),
        "raw_crash_true": sum(1 for r in rows if r["raw_crash_flag"]),
        "raw_crash_exit_code_null": sum(
            1 for r in rows if r["raw_crash_flag"] and r["exit_code"] == ""
        ),
        "true_exception_crash": sum(1 for r in rows if r["audited_outcome"] == "exception_crash"),
        "reclassified_exit_code_unknown": sum(
            1 for r in rows if r["audited_outcome"] == "exited_before_limit_exit_code_unknown"
        ),
        "resource_rule": "post_hoc: sample_count > 0 and peak_working_set_bytes > 0",
        "resource_rule_in_experiment_config": False,
        "bootstrap_seed": SEED,
        "median_definition": "conventional (mean of two central values when n even)",
        "pin_versions": sorted({r["pin_version"] for r in rows if r["pin_version"]}),
        "tomware_sha256": sorted({r["tomware_sha256"] for r in rows if r["tomware_sha256"]}),
    }
    (OUT / "audit_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    outcome_rows = []
    for group in ("benign", "malicious"):
        for profile in ("short_lived", "persistent"):
            for cond in CONDS:
                sub = [r for r in rows if r["group"] == group and r["profile"] == profile and r["condition"] == cond]
                n = len(sub)
                if n == 0:
                    continue
                c = Counter(r["audited_outcome"] for r in sub)
                rec = sum(1 for r in sub if r["protocol_recorded"])
                p, lo, hi = wilson(rec, n)
                unknown = c.get("exited_before_limit_exit_code_unknown", 0)
                outcome_rows.append({
                    "group": group, "profile": profile, "condition": cond, "n": n,
                    "launch_failed": c.get("launch_failed", 0),
                    "exited_before_limit_exit_code_unknown": unknown,
                    "timeout_expired": c.get("timeout_expired", 0),
                    "window_controlled_termination": c.get("window_controlled_termination", 0),
                    "natural_exit": c.get("natural_exit", 0),
                    "exception_crash": c.get("exception_crash", 0),
                    "other": c.get("other", 0),
                    "protocol_recorded": rec,
                    "protocol_recorded_rate": r4(p),
                    "wilson_lo": r4(lo),
                    "wilson_hi": r4(hi),
                    "n_with_resources": sum(1 for r in sub if r["has_resources"]),
                    "n_with_wall": sum(1 for r in sub if r["launch_success"] and r["wall_ms"] > 0),
                })
    wrow(OUT / "outcomes_audited.csv", list(outcome_rows[0].keys()), outcome_rows)

    # metric availability at run and binary level
    avail = []
    for group in ("benign", "malicious"):
        for profile in ("short_lived", "persistent"):
            for cond in CONDS:
                sub = [r for r in rows if r["group"] == group and r["profile"] == profile and r["condition"] == cond]
                if not sub:
                    continue
                n_bin = len({r["sample_id"] for r in sub})
                n_res_bin = len({r["sample_id"] for r in sub if r["has_resources"]})
                avail.append({
                    "group": group, "profile": profile, "condition": cond,
                    "n_runs": len(sub),
                    "n_binaries": n_bin,
                    "n_runs_launch_ok": sum(1 for r in sub if r["launch_success"]),
                    "n_runs_wall": sum(1 for r in sub if r["launch_success"] and r["wall_ms"] > 0),
                    "n_runs_resources": sum(1 for r in sub if r["has_resources"]),
                    "n_binaries_with_any_resource_rep": n_res_bin,
                    "resource_rule": "post_hoc_sample_count_gt_0",
                    "wall_is_performance_metric": profile == "short_lived",
                })
    wrow(OUT / "metric_availability.csv", list(avail[0].keys()), avail)

    buckets = defaultdict(list)
    for r in rows:
        buckets[(r["sample_id"], r["condition"])].append(r)

    sample_med = []
    for (sid, cond), rs in buckets.items():
        m0 = rs[0]
        walls = [x["wall_ms"] for x in rs if x["launch_success"] and x["wall_ms"] > 0]
        cpus = [x["cpu_ms"] for x in rs if x["has_resources"]]
        wss = [x["ws_mb"] for x in rs if x["has_resources"]]
        sample_med.append({
            "sample_id": sid,
            "group": m0["group"],
            "profile": m0["profile"],
            "condition": cond,
            "n_reps": len(rs),
            "n_wall_reps": len(walls),
            "n_resource_reps": len(wss),
            "med_wall_ms": median(walls),
            "med_cpu_ms": median(cpus),
            "med_ws_mb": median(wss),
        })
    wrow(OUT / "sample_condition_medians_audited.csv", list(sample_med[0].keys()), sample_med)

    by_sc = {(s["sample_id"], s["condition"]): s for s in sample_med}
    contrast_rows = []
    flagged = []
    for treat, base in CONTRASTS:
        for group in ("benign", "malicious"):
            for profile in ("short_lived", "persistent"):
                sids = sorted({
                    s["sample_id"] for s in sample_med
                    if s["group"] == group and s["profile"] == profile
                })
                d_wall, d_cpu, d_ws = [], [], []
                n_wall = n_cpu = n_ws = 0
                for sid in sids:
                    a = by_sc.get((sid, treat))
                    b = by_sc.get((sid, base))
                    if not a or not b:
                        continue
                    if a["med_wall_ms"] is not None and b["med_wall_ms"] is not None:
                        d_wall.append(a["med_wall_ms"] - b["med_wall_ms"])
                        n_wall += 1
                    if a["med_cpu_ms"] is not None and b["med_cpu_ms"] is not None:
                        d_cpu.append(a["med_cpu_ms"] - b["med_cpu_ms"])
                        n_cpu += 1
                    if a["med_ws_mb"] is not None and b["med_ws_mb"] is not None:
                        d_ws.append(a["med_ws_mb"] - b["med_ws_mb"])
                        n_ws += 1

                def pack(xs):
                    if not xs:
                        return (None,) * 5
                    q1, q3 = iqr(xs)
                    lo, hi = boot_ci(xs)
                    return median(xs), q1, q3, lo, hi

                mw, w1, w3, wlo, whi = pack(d_wall)
                mc, c1, c3, clo, chi = pack(d_cpu)
                ms, s1, s3, slo, shi = pack(d_ws)
                ws_ci_excludes_zero = (
                    slo is not None and shi is not None and ((slo > 0 and shi > 0) or (slo < 0 and shi < 0))
                )
                wall_ci_excludes_zero = (
                    wlo is not None and whi is not None and ((wlo > 0 and whi > 0) or (wlo < 0 and whi < 0))
                )
                row = {
                    "contrast": f"{treat}-{base}",
                    "group": group,
                    "profile": profile,
                    "n_binaries_in_stratum": len(sids),
                    "n_pairs_wall": n_wall,
                    "n_pairs_cpu": n_cpu,
                    "n_pairs_ws": n_ws,
                    "median_d_wall_ms": r1(mw),
                    "wall_iqr_lo": r1(w1),
                    "wall_iqr_hi": r1(w3),
                    "wall_ci_lo": r1(wlo),
                    "wall_ci_hi": r1(whi),
                    "wall_ci_excludes_zero": ws_bool(wall_ci_excludes_zero, n_wall),
                    "median_d_cpu_ms": r1(mc),
                    "cpu_ci_lo": r1(clo),
                    "cpu_ci_hi": r1(chi),
                    "median_d_ws_mb": r3(ms),
                    "ws_iqr_lo": r3(s1),
                    "ws_iqr_hi": r3(s3),
                    "ws_ci_lo": r3(slo),
                    "ws_ci_hi": r3(shi),
                    "ws_ci_excludes_zero": ws_bool(ws_ci_excludes_zero, n_ws),
                    "resource_rule": "post_hoc_sample_count_gt_0",
                    "wall_is_performance_metric": profile == "short_lived",
                }
                contrast_rows.append(row)
                if treat == "TMW_DM" and base == "TMW0" and group == "malicious" and profile == "short_lived":
                    flagged.append(row)
                if ws_ci_excludes_zero or (wall_ci_excludes_zero and profile == "short_lived"):
                    if treat.startswith("TMW_") and base == "TMW0":
                        flagged.append(row)

    wrow(OUT / "paired_contrasts_audited.csv", list(contrast_rows[0].keys()), contrast_rows)
    if flagged:
        # unique by contrast/group/profile
        seen = set()
        uniq = []
        for r in flagged:
            k = (r["contrast"], r["group"], r["profile"])
            if k not in seen:
                seen.add(k)
                uniq.append(r)
        wrow(OUT / "contrasts_ci_excludes_zero.csv", list(uniq[0].keys()), uniq)

    write_report(summary, outcome_rows, avail, contrast_rows)
    print(json.dumps(summary, indent=2))
    print("wrote", OUT)


def ws_bool(flag, n):
    return "" if n < 2 else ("true" if flag else "false")


def write_report(summary, outcomes, avail, contrasts):
    lines = []
    lines.append("# Auditoria da campanha corpus_aligned_10k (Etapa 2)")
    lines.append("")
    lines.append("Os 9.000 JSON brutos **nao foram alterados**. Esta pasta so contem reclassificacao e agregados.")
    lines.append("")
    lines.append("## Desfechos")
    lines.append("")
    lines.append(f"- JSON: {summary['n_json']} / esperados {summary['n_expected']}; triples unicos: {summary['n_unique_triples']}.")
    lines.append(f"- `raw crash=true`: {summary['raw_crash_true']}; desses, `exit_code` nulo: {summary['raw_crash_exit_code_null']}.")
    lines.append(f"- Reclassificados para `exited_before_limit_exit_code_unknown`: {summary['reclassified_exit_code_unknown']}.")
    lines.append(f"- `exception_crash` verdadeiro (codigo de saida conhecido): {summary['true_exception_crash']}.")
    lines.append("- Motivo: `Invoke-SingleRun.ps1` le `$proc.ExitCode` depois do redirecionamento; nulo comparado com `< 0` vira crash e `exception_code` `0x`.")
    lines.append("- **Nao escrever** no artigo que a maioria das amostras curtas crashou.")
    lines.append("")
    lines.append("## Reclassificacao usada")
    lines.append("")
    lines.append("| audited_outcome | criterio |")
    lines.append("|---|---|")
    lines.append("| launch_failed | launch_success = false |")
    lines.append("| timeout_expired | timeout = true |")
    lines.append("| window_controlled_termination | persistent chegou ao fim da janela |")
    lines.append("| exited_before_limit_exit_code_unknown | crash=true e exit_code nulo e exception_code `0x` |")
    lines.append("| exception_crash | crash=true com codigo de saida conhecido |")
    lines.append("| natural_exit | natural_completion sem o artefato acima |")
    lines.append("")
    lines.append("## Recursos")
    lines.append("")
    lines.append("- Filtro `sample_count > 0` e **post hoc**. Nao consta em `experiment.config.json`.")
    lines.append("- Tempo de parede persistente descreve duracao observada, nao desempenho.")
    lines.append("- `n_pairs_*` nas tabelas de contraste e o n efetivo. Nao usar `n_binaries = 25` quando so 2 pares tem recursos.")
    lines.append("")
    lines.append("## Contraste que NAO inclui zero (nao generalizar como nulo)")
    lines.append("")
    tmw_dm = [
        c for c in contrasts
        if c["contrast"] == "TMW_DM-TMW0" and c["group"] == "malicious" and c["profile"] == "short_lived"
    ]
    if tmw_dm:
        c = tmw_dm[0]
        lines.append(
            f"- TMW_DM - TMW0, malignos curtos, WS: {c['median_d_ws_mb']} MB "
            f"IC95% [{c['ws_ci_lo']}, {c['ws_ci_hi']}] "
            f"(n_pairs_ws={c['n_pairs_ws']}; exclui zero={c['ws_ci_excludes_zero']})."
        )
    lines.append("")
    lines.append("## Frases proibidas nesta revisao")
    lines.append("")
    lines.append("- 31 binarios / 3100 lancamentos / 10 s / 155/155 / -87% / -38% / 9/31.")
    lines.append("- frase: short-lived runs are mostly crash-exit.")
    lines.append("- frase: sample_count > 0 estava fixado a priori no experiment.config.json.")
    lines.append("")
    lines.append("Medianas: convencionais (media dos dois centrais se n par). Bootstrap 2000, seed 705851366. Wilson 95% nas proporcoes.")
    (OUT / "campaign_audit_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
