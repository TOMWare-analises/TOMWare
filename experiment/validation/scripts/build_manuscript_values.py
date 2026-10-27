#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Etapa 9: freeze official manuscript numbers from audited CSVs.

Does not modify the 9000 raw JSON. Does not invent corpus families.
"""
from __future__ import annotations

import csv
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

# experiment/ = parents[2]; validation/ = parents[1]
ROOT = Path(__file__).resolve().parents[2]
VAL = Path(__file__).resolve().parents[1]
RES = ROOT / "results" / "oracles"
OUT = RES
SEED = 705851366


def median(xs):
    xs = sorted(xs)
    n = len(xs)
    if n == 0:
        return None
    mid = n // 2
    return xs[mid] if n % 2 else 0.5 * (xs[mid - 1] + xs[mid])


def wilson(k, n, z=1.96):
    if n <= 0:
        return None, None, None
    p = k / n
    den = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / den
    spread = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return p, max(0.0, centre - spread), min(1.0, centre + spread)


def pct1(x):
    return None if x is None else round(x * 100.0, 1)


def r1(x):
    return None if x is None else round(float(x), 1)


def r3(x):
    return None if x is None else round(float(x), 3)


def parse_float(s):
    if s is None or s == "":
        return None
    return float(str(s).replace(",", ".").replace("%", "").strip())


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def rate_block(k, n):
    p, lo, hi = wilson(k, n)
    return {
        "k": k,
        "n": n,
        "rate": p,
        "pct": pct1(p),
        "wilson_lo_pct": pct1(lo),
        "wilson_hi_pct": pct1(hi),
        "display": f"{pct1(p)}% [{pct1(lo)}, {pct1(hi)}]",
    }


def main():
    audit = RES / "audit"
    if not (audit / "outcomes_audited.csv").exists():
        raise SystemExit(
            "Official numbers are already in results/manuscript_values.json. "
            "Re-run audit_9000.py only if campaigns/corpus_aligned_10k/raw/runs is restored."
        )
    outcomes = read_csv(audit / "outcomes_audited.csv")
    contrasts = read_csv(audit / "paired_contrasts_audited.csv")
    medians = read_csv(audit / "sample_condition_medians_audited.csv")
    corpus = read_csv(ROOT / "corpus" / "corpus.csv")
    timing = read_csv(RES / "matched_timing_n30.csv")
    e5 = read_csv(RES / "counters" / "module_events_by_run.csv")
    e6 = read_csv(RES / "fidelity_by_run.csv")
    e7 = read_csv(RES / "exitcodes_by_run.csv")
    audit_sum = json.loads((audit / "audit_summary.json").read_text(encoding="utf-8"))
    freeze = json.loads((RES / "freeze_meta.json").read_text(encoding="utf-8"))

    included = [r for r in corpus if str(r.get("included", "")).lower() == "true"]
    groups = Counter(r["group"] for r in included)
    profiles = Counter((r["group"], r["execution_profile"]) for r in included)
    arch = Counter(r["architecture"] for r in included)
    families = Counter(r["family_or_product"] for r in included)
    sources = Counter(r["source"] for r in included)
    evasion = Counter(r["targeted_evasion"] for r in included)

    survival = {}
    short_term = {}
    for r in outcomes:
        key = (r["group"], r["profile"], r["condition"])
        n = int(r["n"])
        win = int(r["window_controlled_termination"])
        unknown = int(r["exited_before_limit_exit_code_unknown"])
        timeout = int(r["timeout_expired"])
        fail = int(r["launch_failed"])
        rec = int(r["protocol_recorded"])
        if r["profile"] == "persistent":
            survival[f"{r['group']}.{r['condition']}"] = rate_block(win, n)
        else:
            short_term[f"{r['group']}.{r['condition']}"] = {
                "protocol_recorded": rate_block(rec, n),
                "exited_before_limit_exit_code_unknown": unknown,
                "timeout_expired": timeout,
                "launch_failed": fail,
            }

    contrast_out = []
    for r in contrasts:
        contrast_out.append(
            {
                "contrast": r["contrast"],
                "group": r["group"],
                "profile": r["profile"],
                "n_binaries_in_stratum": int(r["n_binaries_in_stratum"]),
                "n_pairs_wall": int(r["n_pairs_wall"]),
                "n_pairs_ws": int(r["n_pairs_ws"]),
                "median_d_wall_ms": r1(r["median_d_wall_ms"]),
                "wall_ci_lo": r1(r["wall_ci_lo"]),
                "wall_ci_hi": r1(r["wall_ci_hi"]),
                "wall_ci_excludes_zero": r["wall_ci_excludes_zero"] == "true",
                "median_d_ws_mb": r3(r["median_d_ws_mb"]),
                "ws_ci_lo": r3(r["ws_ci_lo"]),
                "ws_ci_hi": r3(r["ws_ci_hi"]),
                "ws_ci_excludes_zero": r["ws_ci_excludes_zero"] == "true",
                "wall_is_performance_metric": r["wall_is_performance_metric"] == "True",
                "do_not_publish_n25_if_pairs_lt_25": int(r["n_pairs_ws"]) < 25
                or int(r["n_pairs_wall"]) < 25,
            }
        )

    wall_of_medians = {}
    for r in medians:
        key = f"{r['group']}.{r['profile']}.{r['condition']}"
        xs = [parse_float(x["med_wall_ms"]) for x in medians if
              x["group"] == r["group"] and x["profile"] == r["profile"]
              and x["condition"] == r["condition"] and x.get("med_wall_ms")]
        wall_of_medians[key] = r1(median(xs)) if xs else None

    timing_by_arm = defaultdict(list)
    for r in timing:
        ticks = parse_float(r["ticks"])
        if ticks is None:
            continue
        timing_by_arm[r["arm"]].append(
            {"ticks": ticks, "below": str(r["below_threshold"]).lower() == "true"}
        )
    timing_out = {}
    for arm, rows in timing_by_arm.items():
        below = sum(1 for x in rows if x["below"])
        med = median([x["ticks"] for x in rows])
        p, lo, hi = wilson(below, len(rows))
        timing_out[arm] = {
            "n": len(rows),
            "below_threshold": below,
            "median_ticks": r3(med),
            "wilson": rate_block(below, len(rows)),
        }

    e5_json = [r for r in e5 if r.get("counters_json_ok") in ("1", "True", "true")]
    e5_tmw0 = [r for r in e5_json if r["arm"] == "TMW0_COUNT"]
    e5_all = [r for r in e5_json if r["arm"] == "TMW_ALL_COUNT"]

    def e5_mod(rows, prefix):
        n = len(rows)
        surf = sum(int(r.get(f"{prefix}_surface") or 0) for r in rows)
        trig = sum(int(r.get(f"{prefix}_triggered") or 0) for r in rows)
        mod = sum(int(r.get(f"{prefix}_modified") or 0) for r in rows)
        return {"n_json": n, "surface": surf, "triggered": trig, "modified": mod}

    e5_out = {
        "n_runs": len(e5),
        "n_json": len(e5_json),
        "n_json_missing": len(e5) - len(e5_json),
        "dll_note": "live-dump 3A3AFB6F... not campaign 4bbc6270...",
        "tmw0_surfaces_all_zero": all(
            int(r.get(k) or 0) == 0
            for r in e5_tmw0
            for k in (
                "ad_surface", "pe_surface", "env_surface", "mc_surface", "sk_surface"
            )
        ),
        "tmw_all": {
            "AntiDebug": e5_mod(e5_all, "ad"),
            "ProcessEnum": e5_mod(e5_all, "pe"),
            "SanitizeEnv": e5_mod(e5_all, "env"),
            "InstMemcmp": e5_mod(e5_all, "mc"),
            "SkewMask": e5_mod(e5_all, "sk"),
            "memcmp_matched_sum": sum(int(r.get("mc_matched") or 0) for r in e5_all),
        },
        "cannot_claim_malware_used_five_checks": True,
    }

    def e6_key(r):
        return (r["sample_id"], r["attempt"])

    by_arm = defaultdict(dict)
    for r in e6:
        by_arm[r["arm"]][e6_key(r)] = r

    def same_exit_stdout(a, b):
        return a.get("exit_code") == b.get("exit_code") and a.get("stdout_sha256") == b.get(
            "stdout_sha256"
        )

    pairs_04 = 0
    same_04 = 0
    for k, a in by_arm["TMW0"].items():
        b = by_arm["TMW_ALL"].get(k)
        if not b:
            continue
        pairs_04 += 1
        if same_exit_stdout(a, b):
            same_04 += 1

    e6_out = {
        "n_runs": len(e6),
        "observer": "external_ps",
        "fidelityprobe_used": False,
        "tmw0_vs_tmw_all_same_exit_stdout": {"same": same_04, "pairs": pairs_04},
        "cannot_claim_behavioral_equivalence": True,
    }

    e7_n = len(e7)
    exits = []
    nulls = 0
    timeouts = 0
    for r in e7:
        raw = r.get("exit_code")
        if raw in (None, "", "null"):
            nulls += 1
            continue
        try:
            code = int(raw)
        except ValueError:
            nulls += 1
            continue
        exits.append(code)
        if code == -2:
            timeouts += 1
    av = sum(1 for c in exits if c == -1073741819)
    dll_nf = sum(1 for c in exits if c == -1073741515)
    e7_out = {
        "n_runs": e7_n,
        "collector_version": "2.1.0",
        "integer_exit": len(exits),
        "null_exit": nulls,
        "timeout_minus2": timeouts,
        "exception_crash_rule_v21": sum(
            1 for c in exits if c != -2 and (c < 0 or c > 65535)
        ),
        "natural_exit_0_65535": sum(1 for c in exits if 0 <= c <= 65535),
        "av_0xC0000005": av,
        "dll_not_found_0xC0000135": dll_nf,
        "does_not_rewrite_9000": True,
    }

    values = {
        "schema": "ieee_access_38745_manuscript_values_v1",
        "frozen_at_local_date": "2026-10-23",
        "campaign": "corpus_aligned_10k",
        "identity": {
            "pin": "3.28.98749",
            "seed": SEED,
            "n_launches": 9000,
            "n_binaries": 100,
            "conditions": 9,
            "reps": 10,
            "window_persistent_s": 60,
            "timeout_short_s": 120,
            "snapshot": "tomware_go",
            "dll_campaign_sha256": freeze["guest_tomware_sha256_values"][0],
            "empty_pintool_sha256": freeze["guest_empty_tool_sha256_values"][0],
            "raw_merkle_sha256": freeze["raw_merkle_sha256"],
            "pdf_overleaf_still_old_sha256": "0FEF4163C6153382AD94E350DAE742105AD9515C84C0D3C2BA03F84FA2AE5851",
            "bootstrap_n": 2000,
            "median": "conventional",
            "resource_rule": "post_hoc sample_count>0 and peak_working_set_bytes>0",
        },
        "corpus_table3": {
            "n_included": len(included),
            "group": dict(groups),
            "strata": {f"{g}_{p}": c for (g, p), c in profiles.items()},
            "architecture": dict(arch),
            "source": dict(sources),
            "family_or_product_coarse": dict(families),
            "targeted_evasion": dict(evasion),
            "publishable_fields": [
                "sample_id",
                "sha256",
                "group",
                "source",
                "acquisition_date",
                "architecture",
                "file_size_bytes",
                "execution_profile",
                "targeted_evasion",
            ],
            "do_not_invent": [
                "VirusTotal family names",
                "packer beyond corpus.csv value",
                "that malware implemented the five hooked checks",
            ],
            "family_note": "Windows_Console_App / Windows_GUI_App / Trojan_Bazaar / Backdoor_Bazaar are coarse labels, not VT consensus.",
        },
        "campaign_9000_outcomes": {
            "raw_termination_reason": audit_sum["raw_termination_reason"],
            "audited_outcome": audit_sum["audited_outcome"],
            "true_exception_crash": 0,
            "do_not_call_6517_crash": True,
            "persistent_survival": survival,
            "short_lived": short_term,
        },
        "table7_contrasts_audited": contrast_out,
        "wall_clock_median_of_per_binary_medians_ms": wall_of_medians,
        "oracles": {
            "antidebug_n3": {
                "AD_GDB": "3/3 BeingDebugged=1 NtGlobalFlag=1 IsDebuggerPresent=1",
                "AD_GDB_DD": "3/3 all zero",
                "AD_NAT_TMW0": "negative controls, all zero",
            },
            "da_five_oracles": "all exit 0; TestOverhead 2040.7 < 3000",
            "pin_without_t_isolated_2026_10_22": "exit 0; campaign omitted PIN because earlier probe failed",
            "timing_n30": timing_out,
            "timing_csv_sha256": "76208218f71b37b8bf3411c0a74932752b96dd133d4db102eebbec25c65b9827",
        },
        "etapa5_counters": e5_out,
        "etapa6_fidelity": e6_out,
        "etapa7_exitcodes": e7_out,
        "etapa8_arancino": {
            "decision": "documented_block",
            "report": "08_arancino/BLOQUEIO.md",
        },
        "future_work": {
            "done_strike_from_paper": [
                "combined -da (item 4)",
                "NAT / EMPTY / TMW0 ladder (item 5)",
                "100-PE corpus + Wilson/bootstrap CIs (half of item 7)",
                "fixed-N=30 timing oracle, all attempts kept",
                "matched AntiDebug -gdb vs -gdb -dd, 3+3",
            ],
            "remain": [
                "AntiDebug beyond BeingDebugged/NtGlobalFlag (NtQueryInformationProcess)",
                "ProcessEnum on NtQuerySystemInformation",
                "RDTSC / RDTSCP and non-intercepted timing sources",
                "API-trace / coverage fidelity (Etapa 6 was external observer only)",
            ],
            "add_requested_2026_10_23": [
                "32-bit: TOMWare Win32 + Pin 3.28 ia32 on 32-bit oracles, then optional 32-bit corpus",
                "Arancino bake-off on a shared 32-bit protocol (Pin 2.14 + VS2010, or a documented port). Current 9000 x64 / Pin 3.28 is not that comparison.",
            ],
        },
        "forbidden_phrases": [
            "31 binaries / 3100 launches / 10 s / 155/155",
            "-87.2% memory / -38.5% CPU as a gain",
            "9/31 re-execution as the current timing result",
            "short-lived runs are mostly crash-exit (of the 9000)",
            "sample_count>0 was a priori in experiment.config.json",
            "malware used the five checks",
            "TOMWare.M outperforms Arancino",
            "behavioral equivalence / transparency",
            "SkewMask always hides Pin",
        ],
    }

    out_json = OUT / "MANUSCRIPT_VALUES.json"
    out_json.write_text(json.dumps(values, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", out_json)
    print("timing", json.dumps(timing_out, indent=2))
    print("e6 same", e6_out["tmw0_vs_tmw_all_same_exit_stdout"])
    print("e7", {k: e7_out[k] for k in ("n_runs", "integer_exit", "null_exit", "av_0xC0000005")})
    print("e5 tmw_all", e5_out["tmw_all"])


if __name__ == "__main__":
    main()
