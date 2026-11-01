# -*- coding: utf-8 -*-
"""Ingest guest r43d (27) + pin_bare_guest_n3 (3). Build CSVs and Tables 25–27."""
from __future__ import annotations

import csv
import json
import shutil
import statistics
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias\TOMWare")
ORACLE = ROOT / "experiment" / "results" / "oracles"
MS = ROOT / "experiment" / "validation" / "manuscript" / "ieee_access_ressubmissao"
DOWNLOADS = Path(r"C:\Users\marge\Downloads")
EXPECTED_PIN = "920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819"
DLL = "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6"
ORACLE_SHA = "3B25069EEBC099593905F6075AF210E9DAE53AD405A5D98C3BB0DFCC0CE1CECD"


def find_dir(name: str) -> Path | None:
    for base in (DOWNLOADS / name, ORACLE / name, ORACLE / "guest" / name):
        if base.is_dir() and any(base.rglob("run_meta.json")):
            return base
    return None


def copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def median_range(xs: list[float]) -> tuple[float, float, float]:
    if not xs:
        return (float("nan"), float("nan"), float("nan"))
    return (statistics.median(xs), min(xs), max(xs))


def named_from_events(run_dir: Path) -> tuple[int, str]:
    names: set[str] = set()
    ev = run_dir / "process_events.jsonl"
    if ev.exists():
        for line in ev.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            n = obj.get("name") or ""
            if n and n != "?":
                names.add(n)
    last = ""
    tree = run_dir / "process_tree.txt"
    if tree.exists():
        last = " | ".join(tree.read_text(encoding="utf-8", errors="replace").splitlines()[:6])
    return len(names), last


def load_runs(d: Path) -> list[dict]:
    rows = []
    for meta in sorted(d.glob("*/run_meta.json")):
        data = json.loads(meta.read_text(encoding="utf-8-sig"))
        n_named_ever, last_tree = named_from_events(meta.parent)
        data["run_dir"] = meta.parent.name
        data["n_named_distinct_during_run"] = n_named_ever
        data["last_tree_excerpt"] = last_tree
        rows.append(data)
    return rows


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def main() -> None:
    pin_src = find_dir("pin_bare_guest_n3")
    tree_src = find_dir("access_r43d")
    if pin_src is None or tree_src is None:
        raise SystemExit(f"missing folders pin={pin_src} tree={tree_src}")

    pin_dst = ORACLE / "guest" / "pin_bare_guest_n3"
    tree_dst = ORACLE / "access_r43d"
    copy_tree(pin_src, pin_dst)
    copy_tree(tree_src, tree_dst)

    rows = load_runs(tree_dst)
    if len(rows) != 27:
        raise SystemExit(f"expected 27 r43d metas, got {len(rows)}")
    pin_mismatch = [
        r for r in rows
        if r.get("mode") != "Native" and str(r.get("pin_sha256", "")).upper() != EXPECTED_PIN
    ]
    if pin_mismatch:
        raise SystemExit(f"{len(pin_mismatch)} instrumented runs are not 920A730A")
    dll_bad = [r for r in rows if str(r.get("dll_sha256", "")).upper() != DLL]
    if dll_bad:
        raise SystemExit(f"{len(dll_bad)} runs have the wrong DLL")

    pin_rows = load_runs(pin_dst)
    if len(pin_rows) != 3:
        raise SystemExit(f"expected 3 pin-bare metas, got {len(pin_rows)}")
    for r in pin_rows:
        if str(r.get("pin_launcher_sha256", "")).upper() != EXPECTED_PIN:
            raise SystemExit("pin-bare launcher is not 920A730A")
        if str(r.get("oracle_sha256", "")).upper() != ORACLE_SHA:
            raise SystemExit("pin-bare oracle SHA mismatch")

    tree_fields = [
        "sample_id", "rep", "mode", "sha256", "progress", "validity",
        "timed_out", "process_stayed_alive_60s", "behavioral_progress_observed",
        "exit_code", "elapsed_ms", "peak_ws", "n_named_last_sample",
        "n_named_distinct_during_run", "root_pid", "elevated",
        "pin_path", "pin_sha256", "pin_sha256_matches_campaign",
        "pin_engine_path", "pin_engine_sha256", "dll_sha256",
        "script_rev", "first_sample_ms", "sample_ms", "identified",
        "last_tree_excerpt", "run_dir",
    ]
    write_csv(tree_dst / "summary.csv", rows, tree_fields)
    write_csv(ORACLE / "access_r43d_summary.csv", rows, tree_fields)

    pin_fields = [
        "rep", "command", "pin_launcher_path", "pin_launcher_sha256",
        "pin_engine_path", "pin_engine_sha256", "oracle_sha256",
        "pin_version_excerpt", "exit_code", "duration_ms", "timed_out",
        "timeout_sec", "startserver_assert", "oracle_ok", "rep_conclusion",
        "script_rev", "run_dir",
    ]
    write_csv(pin_dst / "summary.csv", pin_rows, pin_fields)
    write_csv(ORACLE / "pin_bare_guest_n3_summary.csv", pin_rows, pin_fields)

    cell_rows = []
    t25 = [
        "# Table 25 — `access_r43d_process_tree` (all 27; no cherry-pick)",
        "",
        f"DLL `{DLL}`. Launcher `C:\\TOMWare\\pin\\pin.exe` `{EXPECTED_PIN}`. "
        "N=3, elevated, 50 ms, snapshot `tomware_go`. `identified=false`. "
        "Persistence is not progress. `behavioral_progress_observed=false` on every row.",
        "",
        "| Sample | Mode | Rep | Exit | Elapsed (ms) | 60 s alive | Named last | Named during | Progress |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    order = []
    for sid in ("BEN_28", "BEN_46", "BEN_47"):
        for mode in ("Native", "TMW0", "TMW_DO"):
            for r in sorted(
                [x for x in rows if x.get("sample_id") == sid and x.get("mode") == mode],
                key=lambda x: int(x.get("rep") or 0),
            ):
                order.append(r)
    for r in order:
        t25.append(
            f"| {r.get('sample_id')} | {r.get('mode')} | {r.get('rep')} | {r.get('exit_code')} | "
            f"{r.get('elapsed_ms')} | {r.get('process_stayed_alive_60s')} | "
            f"{r.get('n_named_last_sample')} | {r.get('n_named_distinct_during_run')} | "
            f"{r.get('progress')} |"
        )

    t26 = [
        "# Table 26 — cell medians of Table 25 (n=3). Interval = observed [min, max].",
        "",
        "n=3 is too small for a bootstrap 95% CI. Median and the three-run range only.",
        "",
        "| Sample | Mode | n | Median elapsed (ms) | Range (ms) | n alive 60 s | n named last |",
        "|---|---|---|---|---|---|---|",
    ]
    for sid in ("BEN_28", "BEN_46", "BEN_47"):
        for mode in ("Native", "TMW0", "TMW_DO"):
            cell = [r for r in rows if r.get("sample_id") == sid and r.get("mode") == mode]
            xs = [float(r.get("elapsed_ms") or 0) for r in cell]
            med, lo, hi = median_range(xs)
            n_alive = sum(1 for r in cell if r.get("process_stayed_alive_60s") in (True, "True", "true"))
            n_named = sum(1 for r in cell if int(r.get("n_named_last_sample") or 0) > 0)
            cell_rows.append({
                "sample_id": sid,
                "mode": mode,
                "n": len(cell),
                "median_elapsed_ms": med,
                "min_elapsed_ms": lo,
                "max_elapsed_ms": hi,
                "n_alive_60s": n_alive,
                "n_named_last": n_named,
            })
            t26.append(
                f"| {sid} | {mode} | {len(cell)} | {med:.0f} | [{lo:.0f}, {hi:.0f}] | {n_alive}/3 | {n_named}/3 |"
            )
    write_csv(ORACLE / "access_r43d_cell_medians.csv", cell_rows, list(cell_rows[0].keys()))

    t27 = [
        "# Table 27 — guest Pin-without-Pintool only (campaign launcher)",
        "",
        "Command: `C:\\TOMWare\\pin\\pin.exe -- TestAntiDebug.exe`. "
        f"Launcher `{EXPECTED_PIN}`. Oracle `{ORACLE_SHA}`. "
        "Host StartServer / `FBA632E4` as *launcher* is withdrawn. "
        f"The engine file recorded beside the launcher is `intel64\\bin\\pin.exe` "
        f"`{pin_rows[0].get('pin_engine_sha256')}`. That is not the command that was run.",
        "",
        "| Rep | Launcher SHA-256 | Engine SHA-256 | Oracle SHA-256 | Exit | Duration (ms) | Timeout | Stderr | Conclusion |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for r in sorted(pin_rows, key=lambda x: int(x.get("rep") or 0)):
        t27.append(
            f"| {r.get('rep')} | {r.get('pin_launcher_sha256')} | {r.get('pin_engine_sha256')} | "
            f"{r.get('oracle_sha256')} | {r.get('exit_code')} | {r.get('duration_ms')} | "
            f"{r.get('timed_out')} | empty | {r.get('rep_conclusion')} |"
        )

    (MS / "TABELAS_25_26_27_R43D.md").write_text(
        "\n".join(t25 + [""] + t26 + [""] + t27) + "\n", encoding="utf-8"
    )

    n_alive = sum(1 for r in rows if r.get("process_stayed_alive_60s") in (True, "True", "true"))
    n_prog = sum(1 for r in rows if r.get("behavioral_progress_observed") in (True, "True", "true"))
    man = {
        "pack": "access_r43d_pinbare_closeout",
        "cited_commit": "a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3",
        "dll": DLL,
        "pin_launcher": EXPECTED_PIN,
        "oracle": ORACLE_SHA,
        "pin_bare_n": len(pin_rows),
        "pin_bare_n_ok": sum(1 for r in pin_rows if r.get("rep_conclusion") == "completed_ok"),
        "pin_bare_classification": "campaign_pin_technically_valid_omitted_from_9000_by_design",
        "r43d_n": len(rows),
        "r43d_n_alive_60s": n_alive,
        "r43d_behavioral_progress_observed": n_prog,
        "r43c_note": "access_r43c used intel64 pin FBA632E4 as launcher; not Table 25",
        "pending": [],
        "contains_malware": False,
        "not_a_claim": "alive_is_not_progress; host StartServer is not campaign incompatibility",
        "raw": [
            "experiment/results/oracles/access_r43d/",
            "experiment/results/oracles/guest/pin_bare_guest_n3/",
        ],
    }
    (ORACLE / "r43d_ingest_manifest.json").write_text(json.dumps(man, indent=2) + "\n", encoding="utf-8")
    print("R43D", len(rows), "ALIVE60", n_alive, "PROGRESS", n_prog)
    print("PINBARE", len(pin_rows), "OK", man["pin_bare_n_ok"])
    print("WROTE", MS / "TABELAS_25_26_27_R43D.md")


if __name__ == "__main__":
    main()
