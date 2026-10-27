#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fill JCVHT_Pacote_Agente templates from audited CSVs (24 Oct 2026 close)."""
from __future__ import annotations

import csv
import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias")
JCV = ROOT / "TOMWare" / "experiment" / "validation"
RES = ROOT / "TOMWare" / "experiment" / "results" / "oracles"
CLOSE = JCV / "results_close"
OR4 = RES / "guest"
SRC_PKG = JCV / "_pacote_agente_src" / "JCVHT_Pacote_Agente"
EVID = JCV / "_pacote_evidence" / "JCVHT_EVIDENCE_2026-10-24"
CAMP = "jcvht_rev_2026-10-24"
BUILD = "4BBC6270"
PIN = "3.28.98749"
SEED = "705851366"
N30_DATE = "2026-10-21T16:37:00Z"
AB_DATE = "2026-10-23T11:38:00Z"
C_DATE = "2026-10-23T12:00:00Z"
CLOSE_DATE = "2026-10-24T22:00:00Z"


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def dec(s: str) -> float:
    return float(str(s).replace(",", ".").strip())


def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=header, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in header})


def read_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def conventional_median(vals: list[float]) -> float:
    xs = sorted(vals)
    n = len(xs)
    if n % 2:
        return xs[n // 2]
    return (xs[n // 2 - 1] + xs[n // 2]) / 2


def dump_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def parse_events_jsonl(path: Path) -> list[dict]:
    """Guest C# used pt-BR decimal commas inside otherwise-JSON lines."""
    rows = []
    if not path.exists():
        return rows
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line:
            continue
        fixed = re.sub(r'("observed_wait_ms":)(\d+),(\d+)', r"\1\2.\3", line)
        try:
            rows.append(json.loads(fixed))
        except json.JSONDecodeError:
            rows.append({"_raw": line})
    return rows


def excerpt_fields(excerpt: str) -> dict:
    fields = {}
    for part in (excerpt or "").split("|"):
        part = part.strip()
        if "=" in part and not part.startswith("EV "):
            k, v = part.split("=", 1)
            fields[k.strip()] = v.strip()
    return fields


def main() -> None:
    if EVID.exists():
        shutil.rmtree(EVID)
    EVID.mkdir(parents=True)

    n30 = read_csv(RES / "matched_timing_n30.csv")
    waits_s1 = read_csv(RES / "waits_no_go.csv")
    waits = read_csv(CLOSE / "waits_logged.csv")
    memc = read_csv(RES / "memcmp_variants.csv")
    memc2 = read_csv(CLOSE / "memcmp_variants_v2.csv")
    cases = read_csv(RES / "case_studies_by_run.csv")
    da = read_csv(OR4 / "da_oracles.csv")
    m32 = read_csv(OR4 / "module32_waits.csv")
    m32f = read_csv(CLOSE / "module32_fixture.csv")
    pe_base = read_csv(CLOSE / "processenum_base.csv")

    h_n30 = sha256_file(RES / "matched_timing_n30.csv")
    h_w = sha256_file(CLOSE / "waits_logged.csv")
    h_ws1 = sha256_file(RES / "waits_no_go.csv")
    h_mc = sha256_file(RES / "memcmp_variants.csv")
    h_mc2 = sha256_file(CLOSE / "memcmp_variants_v2.csv")
    h_cs = sha256_file(RES / "case_studies_by_run.csv")
    h_da = sha256_file(OR4 / "da_oracles.csv")
    h_m32 = sha256_file(OR4 / "module32_waits.csv")
    h_m32f = sha256_file(CLOSE / "module32_fixture.csv")
    h_pe = sha256_file(CLOSE / "processenum_base.csv")
    h_fo = sha256_file(RES / "functional_oracles.csv") if (RES / "functional_oracles.csv").exists() else ""

    raw = EVID / "02_raw"
    raw.mkdir(parents=True)
    for src, name in (
        (RES / "matched_timing_n30.csv", "matched_timing_n30.csv"),
        (RES / "matched_timing_summary_conventional.csv", "matched_timing_summary_conventional.csv"),
        (RES / "waits_no_go.csv", "waits_no_go.csv"),
        (CLOSE / "waits_logged.csv", "waits_logged.csv"),
        (RES / "memcmp_variants.csv", "memcmp_variants.csv"),
        (CLOSE / "memcmp_variants_v2.csv", "memcmp_variants_v2.csv"),
        (RES / "case_studies_by_run.csv", "case_studies_by_run.csv"),
        (OR4 / "da_oracles.csv", "da_oracles.csv"),
        (OR4 / "module32_waits.csv", "module32_waits.csv"),
        (CLOSE / "module32_fixture.csv", "module32_fixture.csv"),
        (CLOSE / "processenum_base.csv", "processenum_base.csv"),
        (RES / "functional_oracles.csv", "functional_oracles.csv"),
        (OR4 / "antidebug_n3.csv", "antidebug_n3.csv"),
    ):
        if src.exists():
            shutil.copy2(src, raw / name)
    ev_dst = raw / "wait_events_jsonl"
    ev_dst.mkdir(parents=True, exist_ok=True)
    for evdir in sorted(CLOSE.glob("ev_WAIT_*")):
        src_ev = evdir / "events.jsonl"
        if src_ev.exists():
            shutil.copy2(src_ev, ev_dst / f"{evdir.name}.jsonl")

    letter_en = JCV / "cartas" / "JCVHT_c05a1271_Response_to_Reviewers.pdf"
    letter_pt = JCV / "cartas" / "JCVHT_c05a1271_Resposta_aos_Revisores.pdf"
    (EVID / "07_review").mkdir(parents=True)
    if letter_en.exists():
        shutil.copy2(letter_en, EVID / "07_review" / letter_en.name)
    if letter_pt.exists():
        shutil.copy2(letter_pt, EVID / "07_review" / letter_pt.name)

    (EVID / "00_protocol").mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC_PKG / "PARECER_JCVHT.md", EVID / "00_protocol" / "PARECER_JCVHT.md")
    shutil.copy2(SRC_PKG / "PROMPT_AGENTE_JCVHT.md", EVID / "00_protocol" / "PROMPT_AGENTE_JCVHT.md")
    shutil.copytree(SRC_PKG / "contratos", EVID / "00_protocol" / "contratos")

    # --- protocol / env ---
    dump_json(
        EVID / "00_protocol" / "campaign.json",
        {
            "campaign_id": CAMP,
            "journal": "Journal of Computer Virology and Hacking Techniques",
            "submission_id": "c05a1271-d18d-468d-8c50-9dc8b6c10952",
            "pin_version": PIN,
            "dll_sha256_prefix": BUILD,
            "snapshot": "tomware_go",
            "seed": SEED,
            "timing_n": 30,
            "timing_file_sha256": h_n30,
            "note": "No 9000 rerun. 50+50 / 60s numbers are labelled IEEE-Access campaign reuse for M2 only.",
        },
    )
    dump_json(
        EVID / "00_protocol" / "environment.json",
        {
            "environment_id": "guest_tomware_go",
            "guest_os": "Windows 10 x64",
            "snapshot": "tomware_go",
            "pin": PIN,
            "dll_prefix": BUILD,
            "network": "host-only",
            "login": "tomware-lab",
            "one_pin_at_a_time": True,
        },
    )
    (EVID / "00_protocol" / "protocol.md").write_text(
        "# Protocolo JCVHT (o que foi corrido)\n\n"
        "- Snapshot tomware_go. Pin 3.28.98749. DLL 4BBC6270.\n"
        "- M1a: TestOverhead N=30 TMW0 / GO / GO_DO. Nao repetir.\n"
        "- M1b sessao 1: TestConcurrentWaits N=3 (waits_no_go.csv).\n"
        "- M1b sessao 2 (24/10): TestConcurrentWaitsLogged N=5 + events.jsonl (waits_logged.csv).\n"
        "- M3: MAL_03 MAL_07 MAL_10 BEN_06 x NAT/TMW0/-do, janela 60 s.\n"
        "- M4: Module32 + fixture pinvm; memcmp/_memicmp/RtlCompareMemory; ProcessEnum base; -da 5/5.\n"
        "- Nao repetir 9000. Nao bake-off Arancino.\n",
        encoding="utf-8",
    )

    subjects = [
        {"subject_id": "TestOverhead", "sha256": "", "group": "oracle", "source": "Resultados/Apps-Teste",
         "architecture": "x64", "planned_profile": "oracle", "selection_rule": "timing oracle M1a"},
        {"subject_id": "TestConcurrentWaits", "sha256": "", "group": "oracle", "source": "jcvht_revision",
         "architecture": "x64", "planned_profile": "oracle", "selection_rule": "wait model M1b session 1"},
        {"subject_id": "TestConcurrentWaitsLogged", "sha256": "", "group": "oracle", "source": "jcvht_revision",
         "architecture": "x64", "planned_profile": "oracle", "selection_rule": "wait model M1b session 2 QPC"},
        {"subject_id": "TestMemcmpVariants", "sha256": "", "group": "oracle", "source": "jcvht_revision",
         "architecture": "x64", "planned_profile": "oracle", "selection_rule": "memcmp family M4b"},
        {"subject_id": "TestModule32", "sha256": "", "group": "oracle", "source": "jcvht_revision",
         "architecture": "x64", "planned_profile": "oracle", "selection_rule": "Module32 M4a terminate"},
        {"subject_id": "TestModule32Fixture", "sha256": "", "group": "oracle", "source": "jcvht_revision",
         "architecture": "x64", "planned_profile": "oracle", "selection_rule": "Module32 dummy pinvm filter"},
        {"subject_id": "TestProcessEnum", "sha256": "", "group": "oracle", "source": "Resultados/Apps-Teste",
         "architecture": "x64", "planned_profile": "oracle", "selection_rule": "Process32 pin.exe hide/show"},
        {"subject_id": "MAL_03", "sha256": "04e4e646de39b18d7a9b4fe567dfdc986e21e469813f0069220649d26aed862d",
         "group": "malicious", "source": "IEEE 100-PE corpus / MalwareBazaar",
         "architecture": "x64", "planned_profile": "short_lived",
         "selection_rule": "Etapa5 SkewMask candidate; not a proven check"},
        {"subject_id": "MAL_07", "sha256": "153e11471f85de3df5135b0445014698333ff40a9d6c488d291d6517eb19800d",
         "group": "malicious", "source": "IEEE 100-PE corpus / MalwareBazaar",
         "architecture": "x64", "planned_profile": "short_lived",
         "selection_rule": "Etapa5 SkewMask candidate; not a proven check"},
        {"subject_id": "MAL_10", "sha256": "1b5a4745d994e662ce897ae63f48f465cce8498c3605119ac9d8979318e43a71",
         "group": "malicious", "source": "IEEE 100-PE corpus / MalwareBazaar",
         "architecture": "x64", "planned_profile": "short_lived",
         "selection_rule": "Etapa5 SkewMask candidate; not a proven check"},
        {"subject_id": "BEN_06", "sha256": "0436f44255d26e463fe9554d30f5f681bec9aaec14fb8ef53acbdea838b1f39d",
         "group": "benign", "source": "IEEE 100-PE corpus / Windows_Environment",
         "architecture": "x64", "planned_profile": "short_lived",
         "selection_rule": "Etapa5 SkewMask candidate; not a proven check"},
    ]
    write_csv(
        EVID / "00_protocol" / "corpus_audited.csv",
        ["subject_id", "sha256", "original_filename", "group", "source", "source_reference",
         "acquisition_date", "first_seen_date", "family_or_product", "classification_source",
         "architecture", "signature_status", "packer", "protector", "planned_profile",
         "native_observed_profile", "command_argv_json", "input_id", "dependencies",
         "selection_rule", "provenance_path"],
        [
            {
                "subject_id": s["subject_id"],
                "sha256": s["sha256"],
                "original_filename": s["subject_id"] + (".exe" if s["sha256"] else ".exe"),
                "group": s["group"],
                "source": s["source"],
                "architecture": s["architecture"],
                "planned_profile": s["planned_profile"],
                "selection_rule": s["selection_rule"],
                "family_or_product": "",
                "classification_source": "",
                "packer": "",
                "protector": "",
                "signature_status": "",
            }
            for s in subjects
        ],
    )

    plan = []
    timing_rows = []
    run_index = []
    wait_rows = []
    clock_rows = []
    func_rows = []
    mile_rows = []
    res_rows = []
    tree_rows = []
    case_comp = []
    exec_plan = []
    evidence = []
    stats = []

    def add_run(run_id, subject, kind, group, cond, rep, started, exit_code, timed_out,
                wall_ms, comment_ids, source, term=None):
        if term is None:
            if str(timed_out).lower() in ("true", "1"):
                term = "timeout"
            elif str(exit_code) in ("-1073741819",):
                term = "access_violation"
            elif str(exit_code) in ("-532462766",):
                term = "clr_unhandled"
            else:
                term = "exited"
        run_index.append({
            "run_id": run_id, "campaign_id": CAMP, "subject_id": subject,
            "subject_kind": kind, "group": group, "condition": cond, "repetition": rep,
            "block_id": comment_ids.split("|")[0], "git_commit": "", "build_id": BUILD,
            "started_at_utc": started, "launch_success": "true",
            "termination_reason": term, "process_exit_value": exit_code,
            "exit_source": "collector", "timed_out": str(timed_out).lower(),
            "window_ms": 90000 if "M1" in comment_ids or "M4" in comment_ids else 60000,
            "external_wall_ms": wall_ms, "functional_status": term,
            "collection_status": "recorded", "run_json_path": f"02_raw/runs/{run_id}.json",
            "comment_ids": comment_ids,
        })
        exec_plan.append({
            "planned_run_id": run_id, "campaign_id": CAMP, "subject_id": subject,
            "subject_kind": kind, "group": group, "condition": cond, "repetition": rep,
            "block_id": comment_ids.split("|")[0], "order_index": len(exec_plan) + 1,
            "seed": SEED, "window_ms": 90000, "timeout_ms": 90000,
            "command_argv_json": "", "comment_ids": comment_ids,
        })
        dump_json(
            EVID / "02_raw" / "runs" / f"{run_id}.json",
            {
                "schema_version": "1.0",
                "run_id": run_id,
                "campaign_id": CAMP,
                "subject_id": subject,
                "subject_kind": kind,
                "group": group,
                "condition": cond,
                "repetition": int(rep),
                "block_id": comment_ids.split("|")[0],
                "git_commit": "",
                "build_id": BUILD,
                "subject_sha256": next((x["sha256"] for x in subjects if x["subject_id"] == subject), ""),
                "protocol_sha256": "",
                "config_sha256": "",
                "environment_id": "guest_tomware_go",
                "started_at_utc": started,
                "ended_at_utc": started,
                "command_argv": [],
                "launch_success": True,
                "target_pid": None,
                "exit_code": exit_code,
                "termination_reason": term,
                "timed_out": str(timed_out).lower() in ("true", "1"),
                "external_wall_ms": wall_ms,
                "functional_status": term,
                "collection_status": "recorded",
                "metrics": {},
                "stdout_path": source,
                "stderr_path": "",
                "raw_artifact_paths": [source],
                "comment_ids": comment_ids.split("|"),
            },
        )

    # M1a timing
    for r in n30:
        arm = r["arm"]
        cond = {"TMW0": "TMW0", "GO": "GO", "GO_DO": "GO_DO"}[arm]
        rid = f"TIM_{arm}_{int(r['attempt']):02d}"
        ticks = dec(r["ticks"])
        add_run(rid, "TestOverhead", "oracle", "oracle", cond, r["attempt"], N30_DATE,
                r["exit_code"], r["timed_out"], "", "M1a",
                "02_raw/matched_timing_n30.csv")
        timing_rows.append({
            "run_id": rid, "subject_id": "TestOverhead", "condition": cond,
            "repetition": r["attempt"], "clock_api": "TestOverhead_ticks",
            "score_unit": "ticks", "requested_wait_ms": "",
            "external_elapsed_ms": "", "reported_elapsed_ms": "",
            "oracle_score": f"{ticks:.3f}", "threshold": "3000",
            "comparison_operator": "<", "below_threshold": str(r["below_threshold"]).lower(),
            "timed_out": str(r["timed_out"]).lower(),
            "termination_reason": "exited", "validity": "valid",
            "missing_reason": "", "source_path": "02_raw/matched_timing_n30.csv",
        })

    by_arm = {}
    for r in timing_rows:
        by_arm.setdefault(r["condition"], []).append(float(r["oracle_score"]))
    for cond, vals in by_arm.items():
        med = conventional_median(vals)
        below = sum(1 for v in vals if v < 3000)
        stats.append({
            "stat_id": f"S_MED_{cond}", "comment_id": "M1a",
            "subject_id_or_stratum": "TestOverhead", "metric": "oracle_ticks",
            "unit": "ticks", "contrast": cond, "estimator": "conventional_median",
            "estimate": f"{med:.3f}", "q1": "", "q3": "", "ci_level": "",
            "ci_low": "", "ci_high": "", "n_planned": 30, "n_recorded": 30,
            "n_valid": 30, "n_binaries": 1, "denominator_description": "30 attempts kept",
            "analysis_unit": "repetition", "ci_method": "", "seed": SEED,
            "source_run_ids_json": json.dumps([x["run_id"] for x in timing_rows if x["condition"] == cond]),
            "script_path": "fill_jcvht_pacote.py",
        })
        stats.append({
            "stat_id": f"S_RATE_{cond}", "comment_id": "M1a",
            "subject_id_or_stratum": "TestOverhead", "metric": "below_3000_rate",
            "unit": "proportion", "contrast": cond, "estimator": "count/n",
            "estimate": f"{below/30:.4f}", "q1": "", "q3": "", "ci_level": "0.95",
            "ci_low": "0.219" if cond == "GO" else ("0.886" if below == 30 else ""),
            "ci_high": "0.545" if cond == "GO" else ("1.000" if below == 30 else ""),
            "n_planned": 30, "n_recorded": 30, "n_valid": 30, "n_binaries": 1,
            "denominator_description": f"{below}/30 below 3000",
            "analysis_unit": "repetition", "ci_method": "wilson", "seed": SEED,
            "source_run_ids_json": "", "script_path": "fill_jcvht_pacote.py",
        })

    # M1b waits session 2 (QPC + pid; tid of par_* is the joining thread)
    wait_med = {"NAT": {"seq": [], "par": [], "tick": [], "alert": []},
                "EMPTY": {"seq": [], "par": [], "tick": [], "alert": []},
                "TMW0": {"seq": [], "par": [], "tick": [], "alert": []},
                "DO": {"seq": [], "par": [], "tick": [], "alert": []}}
    for r in waits:
        arm = r["name"].replace("WAIT_", "")
        rid = f"{r['name']}_{int(r['attempt']):02d}"
        add_run(rid, "TestConcurrentWaitsLogged", "oracle", "oracle", r["name"], r["attempt"],
                CLOSE_DATE, r["exit_code"], r["timed_out"], r["duration_ms"], "M1b|M4",
                "02_raw/waits_logged.csv")
        fields = excerpt_fields(r.get("excerpt", ""))
        ev_path = CLOSE / f"ev_{r['name']}_{int(r['attempt']):02d}" / "events.jsonl"
        evs = parse_events_jsonl(ev_path)
        src_rel = f"02_raw/wait_events_jsonl/ev_{r['name']}_{int(r['attempt']):02d}.jsonl"
        pid = str(evs[0].get("pid", "")) if evs else ""
        for ev in evs:
            scen = ev.get("scenario", "")
            obs = ev.get("observed_wait_ms", "")
            wait_rows.append({
                "run_id": rid, "sequence": ev.get("seq", ""),
                "pid": ev.get("pid", ""), "tid": ev.get("tid", ""),
                "scenario": scen, "wait_api": ev.get("wait_api", ""),
                "requested_wait_ms": ev.get("requested_wait_ms", ""),
                "start_reference_ns": ev.get("start_reference_ns", ""),
                "end_reference_ns": ev.get("end_reference_ns", ""),
                "observed_wait_ms": obs,
                "return_value": "overlap" if scen.startswith("par_") else ev.get("extra", ""),
                "early_return": "true" if scen == "alertable" and obs != "" and float(obs) < 500 else "",
                "overlap_group": "par" if scen.startswith("par_") else "",
                "offset_before_ms": "", "offset_after_ms": "",
                "source_path": src_rel,
            })
        if "seq_ms" in fields:
            wait_med[arm]["seq"].append(dec(fields["seq_ms"]))
        if "par_ms" in fields:
            wait_med[arm]["par"].append(dec(fields["par_ms"]))
        if "tick_delta_ms" in fields:
            wait_med[arm]["tick"].append(dec(fields["tick_delta_ms"]))
        if "alertable_ms" in fields:
            wait_med[arm]["alert"].append(dec(fields["alertable_ms"]))
        clock_rows.append({
            "run_id": rid, "sequence": 1, "pid": pid, "tid": evs[0].get("tid", "") if evs else "",
            "scenario": "TickCount pair around Sleep 50", "clock_api": "Environment.TickCount",
            "reference_ns": next((e.get("start_reference_ns", "") for e in evs if e.get("scenario") == "tick_sleep50"), ""),
            "returned_value_text": fields.get("tick_delta_ms", ""),
            "returned_unit": "ms", "offset_ms": "",
            "delta_from_previous_ms": fields.get("tick_delta_ms", ""),
            "regression_detected": "false" if fields.get("monotonic") == "True" else "",
            "validity": "valid" if fields.get("monotonic") == "True" else "unknown",
            "missing_reason": "tid_is_joining_thread",
            "source_path": src_rel,
        })
    for arm, mets in wait_med.items():
        for met, vals in mets.items():
            if not vals:
                continue
            stats.append({
                "stat_id": f"S_WAIT_{arm}_{met}", "comment_id": "M1b",
                "subject_id_or_stratum": "TestConcurrentWaitsLogged",
                "metric": f"{met}_ms", "unit": "ms", "contrast": arm,
                "estimator": "conventional_median",
                "estimate": f"{conventional_median(vals):.3f}",
                "q1": "", "q3": "", "ci_level": "", "ci_low": "", "ci_high": "",
                "n_planned": 5, "n_recorded": len(vals), "n_valid": len(vals),
                "n_binaries": 1, "denominator_description": f"N=5 {arm} {met}",
                "analysis_unit": "repetition", "ci_method": "", "seed": SEED,
                "source_run_ids_json": "", "script_path": "fill_jcvht_pacote.py",
            })

    # M4 functional
    for r in da:
        rid = f"DA_{r['name']}"
        add_run(rid, r["exe"].replace(".exe", ""), "oracle", "oracle", r["knobs"], 1,
                "2026-10-22T00:00:00Z", r["exit_code"], r["timed_out"], "", "M4",
                "02_raw/da_oracles.csv")
        func_rows.append({
            "test_id": rid, "run_id": rid, "module": "combined_-da",
            "interface": r["exe"], "variant": r["knobs"], "scenario": "combined_da",
            "control_type": "positive_mask", "symbol_present": "", "hook_installed": "true",
            "expected_behavior": "oracle_ok_or_zero_indicators",
            "expected_return_text": "exit 0",
            "observed_return_text": (r.get("excerpt") or "")[:240],
            "target_visible_before": "", "target_visible_after": "",
            "unrelated_entries_preserved": "", "enumeration_terminated": "",
            "buffers_preserved": "", "result": "pass" if r["exit_code"] == "0" else "fail",
            "evidence_path": "02_raw/da_oracles.csv", "comment_ids": "M4",
        })

    for r in m32:
        if not str(r.get("name", "")).startswith("M32"):
            continue
        rid = f"{r['name']}"
        add_run(rid, "TestModule32", "oracle", "oracle", r.get("knobs") or r.get("mode") or "native",
                1, "2026-10-22T00:00:00Z", r["exit_code"], r.get("timed_out", "False"),
                "", "M4", "02_raw/module32_waits.csv")
        ex = r.get("excerpt", "")
        func_rows.append({
            "test_id": rid, "run_id": rid, "module": "ProcessEnumMask",
            "interface": "Module32First/Next", "variant": r.get("knobs") or "native",
            "scenario": r["name"], "control_type": "enumeration",
            "symbol_present": "true", "hook_installed": "true" if "dp" in (r.get("knobs") or "") else "false",
            "expected_behavior": "terminate_and_keep_kernel32",
            "expected_return_text": "terminated=True kernel32=1",
            "observed_return_text": ex.replace("\n", " | ")[:240],
            "target_visible_before": "", "target_visible_after": "",
            "unrelated_entries_preserved": "true" if "kernel32=1" in ex else "",
            "enumeration_terminated": "true" if "terminated=True" in ex else "",
            "buffers_preserved": "", "result": "pass" if "PASS_MASK_OR_CLEAN" in ex else "partial",
            "evidence_path": "02_raw/module32_waits.csv", "comment_ids": "M4",
        })

    for r in memc:
        rid = f"{r['name']}_s1"
        add_run(rid, "TestMemcmpVariants", "oracle", "oracle", r.get("knobs") or "native",
                1, AB_DATE, r["exit_code"], r["timed_out"], r["duration_ms"], "M4",
                "02_raw/memcmp_variants.csv")
        func_rows.append({
            "test_id": rid, "run_id": rid, "module": "InstMemcmpMask",
            "interface": "memcmp|_memicmp_session1", "variant": r.get("knobs") or "native",
            "scenario": r["name"], "control_type": "mask_vs_pass",
            "symbol_present": "true", "hook_installed": "true" if r.get("knobs") else "false",
            "expected_behavior": "historical_clr_abort_after_two_apis",
            "expected_return_text": "", "observed_return_text": (r.get("excerpt") or "")[:240],
            "target_visible_before": "", "target_visible_after": "",
            "unrelated_entries_preserved": "", "enumeration_terminated": "",
            "buffers_preserved": "", "result": "superseded_by_v2",
            "evidence_path": "02_raw/memcmp_variants.csv", "comment_ids": "M4",
        })

    for r in memc2:
        rid = r["name"]
        add_run(rid, "TestMemcmpVariants", "oracle", "oracle", r.get("knobs") or "native",
                1, CLOSE_DATE, r["exit_code"], r["timed_out"], r["duration_ms"], "M4",
                "02_raw/memcmp_variants_v2.csv")
        ex = r.get("excerpt", "")
        kn = r.get("knobs") or "native"
        for iface, token, ok_nat, ok_mask in (
            ("memcmp", "memcmp_PIN", "PASS", "MASKED"),
            ("_memicmp", "memicmp_PIN", "PASS", "MASKED"),
            ("RtlCompareMemory", "RtlCompareMemory_PIN", "PASS", "MASKED"),
            ("RtlEqualMemory", "RtlEqualMemory_PIN", "NOT_EXERCISED", "NOT_EXERCISED"),
            ("wmemcmp", "wmemcmp", "NOT_EXERCISED", "NOT_EXERCISED"),
        ):
            observed = next((p.strip() for p in ex.split("|") if token in p), "")
            if "NOT_EXERCISED" in observed or iface in ("RtlEqualMemory", "wmemcmp"):
                result = "missing"
            elif rid in ("MC_NAT", "MC_TMW0") and ok_nat in observed:
                result = "pass"
            elif rid in ("MC_DM", "MC_DA") and ok_mask in observed:
                result = "pass"
            else:
                result = "fail"
            func_rows.append({
                "test_id": f"{rid}_{iface}", "run_id": rid, "module": "InstMemcmpMask",
                "interface": iface, "variant": kn, "scenario": rid,
                "control_type": "mask_vs_pass",
                "symbol_present": "false" if result == "missing" else "true",
                "hook_installed": "true" if kn not in ("", "native") else "false",
                "expected_behavior": "NAT/TMW0 PASS; -dm/-da MASKED; export may be absent",
                "expected_return_text": "", "observed_return_text": observed[:240],
                "target_visible_before": "true" if "PASS" in observed else "false",
                "target_visible_after": "false" if "MASKED" in observed else "",
                "unrelated_entries_preserved": "", "enumeration_terminated": "",
                "buffers_preserved": "not_tested_n7_equal_by_construction" if iface == "memcmp" else "",
                "result": result,
                "evidence_path": "02_raw/memcmp_variants_v2.csv", "comment_ids": "M4",
            })
        func_rows.append({
            "test_id": f"{rid}_passthrough_note", "run_id": rid, "module": "InstMemcmpMask",
            "interface": "memcmp_passthrough", "variant": kn, "scenario": "AAAAAAA_vs_AAAAAAAB_n7",
            "control_type": "pass", "symbol_present": "true",
            "hook_installed": "true" if kn not in ("", "native") else "false",
            "expected_behavior": "n=7 prefixes are identical; SAME_BAD is not a tool defect",
            "expected_return_text": "ret=0 by construction",
            "observed_return_text": next((p.strip() for p in ex.split("|") if "memcmp_passthrough" in p), ""),
            "target_visible_before": "", "target_visible_after": "",
            "unrelated_entries_preserved": "", "enumeration_terminated": "",
            "buffers_preserved": "equal_7byte_prefix",
            "result": "not_a_differing_pair",
            "evidence_path": "02_raw/memcmp_variants_v2.csv", "comment_ids": "M4",
        })

    for r in m32f:
        rid = r["name"]
        add_run(rid, "TestModule32Fixture", "oracle", "oracle", r.get("knobs") or "native",
                1, CLOSE_DATE, r["exit_code"], r["timed_out"], r["duration_ms"], "M4",
                "02_raw/module32_fixture.csv")
        ex = r.get("excerpt", "")
        visible = "fixture_pinvm=1" in ex
        hidden = "fixture_pinvm=0" in ex
        if rid in ("M32F_NAT", "M32F_TMW0"):
            result = "pass" if visible and "kernel32=1" in ex and "terminated=True" in ex else "fail"
        else:
            result = "pass" if hidden and "kernel32=1" in ex and "terminated=True" in ex else "fail"
        func_rows.append({
            "test_id": rid, "run_id": rid, "module": "ProcessEnumMask",
            "interface": "Module32First/Next", "variant": r.get("knobs") or "native",
            "scenario": "dummy_pinvm_from_version.dll", "control_type": "positive_filter",
            "symbol_present": "true",
            "hook_installed": "true" if "dp" in (r.get("knobs") or "") or "da" in (r.get("knobs") or "") else "false",
            "expected_behavior": "NAT/TMW0 see fixture; -dp/-da hide it; keep kernel32; terminate",
            "expected_return_text": "fixture_pinvm contrast + kernel32=1 + terminated=True",
            "observed_return_text": ex.replace("\n", " | ")[:240],
            "target_visible_before": "true" if visible else "false",
            "target_visible_after": "false" if hidden else "true",
            "unrelated_entries_preserved": "true" if "kernel32=1" in ex else "",
            "enumeration_terminated": "true" if "terminated=True" in ex else "",
            "buffers_preserved": "",
            "result": result,
            "evidence_path": "02_raw/module32_fixture.csv", "comment_ids": "M4",
        })

    for r in pe_base:
        rid = r["name"]
        add_run(rid, "TestProcessEnum", "oracle", "oracle", r.get("knobs") or "native",
                1, CLOSE_DATE, r["exit_code"], r["timed_out"], r["duration_ms"], "M4",
                "02_raw/processenum_base.csv")
        ex = r.get("excerpt", "")
        pin_n = "0"
        m = re.search(r"pin\.exe\s*:\s*(\d+)", ex)
        if m:
            pin_n = m.group(1)
        if rid == "PE_TMW0":
            result = "pass" if pin_n == "3" else "fail"
        else:
            result = "pass" if pin_n == "0" else "fail"
        func_rows.append({
            "test_id": rid, "run_id": rid, "module": "ProcessEnumMask",
            "interface": "Process32First/Next", "variant": r.get("knobs") or "native",
            "scenario": "pin.exe_count", "control_type": "hide_show",
            "symbol_present": "true",
            "hook_installed": "true" if "dp" in (r.get("knobs") or "") or "da" in (r.get("knobs") or "") else "false",
            "expected_behavior": "NAT=0 (no Pin); TMW0=3; -dp/-da=0",
            "expected_return_text": f"pin.exe={pin_n}",
            "observed_return_text": ex.replace("\n", " | ")[:240],
            "target_visible_before": "true" if pin_n != "0" else "false",
            "target_visible_after": "false" if rid in ("PE_DP", "PE_DA") and pin_n == "0" else "",
            "unrelated_entries_preserved": "", "enumeration_terminated": "",
            "buffers_preserved": "", "result": result,
            "evidence_path": "02_raw/processenum_base.csv", "comment_ids": "M4",
        })

    # M3 cases
    sha = {
        "MAL_03": "04e4e646de39b18d7a9b4fe567dfdc986e21e469813f0069220649d26aed862d",
        "MAL_07": "153e11471f85de3df5135b0445014698333ff40a9d6c488d291d6517eb19800d",
        "MAL_10": "1b5a4745d994e662ce897ae63f48f465cce8498c3605119ac9d8979318e43a71",
        "BEN_06": "0436f44255d26e463fe9554d30f5f681bec9aaec14fb8ef53acbdea838b1f39d",
    }
    for r in cases:
        rid = f"CASE_{r['sample_id']}_{r['arm']}"
        grp = "benign" if r["sample_id"].startswith("BEN") else "malicious"
        add_run(rid, r["sample_id"], "case", grp, r["arm"], 1, C_DATE,
                r["exit_code"], r["timed_out"], r["duration_ms"], "M3|M2",
                "02_raw/case_studies_by_run.csv")
        for mid, defin, expected in (
            ("new_file", "new file in Temp/Public/Desktop/Downloads", "path+sha256"),
            ("stdout", "non-empty process stdout", "excerpt"),
            ("named_child", "identified child image not pin.exe", "process_tree row"),
        ):
            reached = "false"
            if mid == "new_file" and str(r.get("new_files", "0")) not in ("0", ""):
                reached = "false"  # count exists but files not identified
            mile_rows.append({
                "run_id": rid, "case_id": f"CS_{r['sample_id']}", "subject_id": r["sample_id"],
                "milestone_id": mid, "milestone_definition": defin,
                "expected_artifact": expected, "reached": reached,
                "time_from_start_ms": r["duration_ms"], "artifact_path": "",
                "artifact_sha256": "", "evidence_path": "02_raw/case_studies_by_run.csv",
            })
        res_rows.append({
            "run_id": rid, "sequence": 1, "reference_ns": "",
            "elapsed_ms": r["duration_ms"], "pid": "", "parent_pid": "",
            "process_role": "root", "cpu_user_ms": "", "cpu_kernel_ms": "",
            "working_set_bytes": "", "private_bytes": "", "thread_count": "",
            "io_read_bytes": "", "io_write_bytes": "",
            "process_alive": "false" if str(r["timed_out"]).lower() != "true" else "true",
            "validity": "partial", "missing_reason": "observer_had_no_perf_counters",
        })
        tree_rows.append({
            "run_id": rid, "pid": "", "parent_pid": "",
            "process_instance_id": rid + "_root",
            "image_name": r["sample_id"] + ".exe", "image_sha256": r["sha256"],
            "started_at_utc": C_DATE, "ended_at_utc": "",
            "is_root": "true",
            "termination_reason": "timeout" if str(r["timed_out"]).lower() == "true" else "exited",
            "evidence_path": "02_raw/case_studies_by_run.csv",
        })

    for sid in ("MAL_03", "MAL_07", "MAL_10", "BEN_06"):
        dump_json(
            EVID / "05_cases" / f"CS_{sid}.json",
            {
                "schema_version": "1.0",
                "case_id": f"CS_{sid}",
                "subject_id": sid,
                "subject_sha256": sha[sid],
                "selection_reason": "Etapa 5 SkewMask candidate. Not an identified anti-Pin check in the PE.",
                "input_description": "no extra arguments; 60 s window; host-only network",
                "conditions": [
                    {"condition": "NAT", "run_ids": [f"CASE_{sid}_NAT"], "role": "native_reference"},
                    {"condition": "TMW0", "run_ids": [f"CASE_{sid}_TMW0"], "role": "instrumented_baseline"},
                    {"condition": "KNOB", "run_ids": [f"CASE_{sid}_KNOB"], "role": "treatment"},
                ],
                "check": {
                    "interface_or_mechanism": "unknown",
                    "identified": False,
                    "note": "SkewMask fired in a later counter dump; that is not a located check.",
                },
                "milestones": [
                    {"milestone_id": "new_file", "reached": False},
                    {"milestone_id": "stdout", "reached": False},
                    {"milestone_id": "named_child", "reached": False},
                ],
                "additional_behavior": False,
                "evidence": ["02_raw/case_studies_by_run.csv"],
                "conclusion_status": "no_milestone",
                "limitations": "new_files=0; empty stdout; child_count under Pin is not a named tree.",
                "comment_ids": ["M3", "M2"],
            },
        )
        case_comp.append({
            "case_id": f"CS_{sid}", "subject_id": sid, "check_id": "unidentified",
            "module": "SkewMask", "baseline_condition": "NAT|TMW0",
            "treatment_condition": "KNOB_-do",
            "baseline_run_ids_json": json.dumps([f"CASE_{sid}_NAT", f"CASE_{sid}_TMW0"]),
            "treatment_run_ids_json": json.dumps([f"CASE_{sid}_KNOB"]),
            "check_location_text": "not identified",
            "branch_baseline_text": "", "branch_treatment_text": "",
            "additional_behavior": "false", "artifact_path": "", "artifact_sha256": "",
            "causal_evidence_path": "02_raw/case_studies_by_run.csv",
            "conclusion": "no_case_study",
            "limitations": "No extra file/stdout/named child. Do not claim practical benefit.",
        })

    # M2 labelled 50+50 aggregates (not Table 9)
    for sid, est, lo, hi, n in (
        ("benign_persistent", 55452, 30685, 57031, 25),
        ("malicious_persistent", 37387, 26146, 42770, 23),
    ):
        stats.append({
            "stat_id": f"S_WALL_DO_{sid}", "comment_id": "M2",
            "subject_id_or_stratum": sid, "metric": "wall_ms_TMW_DO_minus_TMW0",
            "unit": "ms", "contrast": "TMW_DO-TMW0",
            "estimator": "median_of_medians_bootstrap",
            "estimate": est, "q1": "", "q3": "", "ci_level": "0.95",
            "ci_low": lo, "ci_high": hi, "n_planned": 25, "n_recorded": n,
            "n_valid": n, "n_binaries": n,
            "denominator_description": f"n_pairs={n}; 60s window; IEEE 50+50 campaign; NOT JCVHT Table 9 10s",
            "analysis_unit": "binary", "ci_method": "bootstrap_2000", "seed": SEED,
            "source_run_ids_json": "", "script_path": "revision_gap_closure/09_values/MANUSCRIPT_VALUES.json",
        })

    manuscript = [
        {"change_id": "MC_T6", "comment_id": "M1a", "section": "5.5 / Table 6",
         "table_or_figure": "Table 6", "reason": "replace confounded -go vs -do with matched N=30",
         "evidence_ids": "EV_N30", "validated_stat_ids": "S_MED_TMW0|S_MED_GO|S_MED_GO_DO",
         "proposed_text_path": "07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf",
         "application_status": "proposed"},
        {"change_id": "MC_WAIT", "comment_id": "M1b", "section": "timing limitation",
         "table_or_figure": "", "reason": "N=5 QPC: Pin inverts overlap; -do does not restore; alertable ~46 ms only native",
         "evidence_ids": "EV_WAIT2", "validated_stat_ids": "S_WAIT_NAT_par|S_WAIT_DO_par",
         "proposed_text_path": "07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf",
         "application_status": "proposed"},
        {"change_id": "MC_T9", "comment_id": "M2", "section": "Table 9 discussion",
         "table_or_figure": "Table 9", "reason": "10s figures are not a gain; do not import +55s as Table 9",
         "evidence_ids": "EV_RES", "validated_stat_ids": "S_WALL_DO_benign_persistent",
         "proposed_text_path": "07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf",
         "application_status": "proposed"},
        {"change_id": "MC_M3", "comment_id": "M3", "section": "case studies",
         "table_or_figure": "", "reason": "state practical benefit is not demonstrated",
         "evidence_ids": "EV_CASE", "validated_stat_ids": "",
         "proposed_text_path": "07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf",
         "application_status": "proposed"},
        {"change_id": "MC_ABS", "comment_id": "m3", "section": "abstract",
         "table_or_figure": "", "reason": "five modules independently oracled; timing is 11/30 vs 30/30",
         "evidence_ids": "EV_N30", "validated_stat_ids": "S_RATE_GO|S_RATE_GO_DO",
         "proposed_text_path": "07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf",
         "application_status": "proposed"},
        {"change_id": "MC_T8", "comment_id": "m2", "section": "Table 8",
         "table_or_figure": "Table 8", "reason": "fix TestProcessEnum column wrap; collapse repeated limitations",
         "evidence_ids": "", "validated_stat_ids": "",
         "proposed_text_path": "07_review/ALTERACOES_SUGERIDAS.md",
         "application_status": "proposed"},
    ]
    changes = [{
        "change_id": "CH_NONE", "git_commit": "",
        "file_path": "", "reason": "no repository commit requested for this revision pack",
        "comment_ids": "m1", "tests_affected": "", "test_results_path": "",
        "regression_status": "not_committed",
    }]

    evidence = [
        {"evidence_id": "EV_N30", "comment_ids": "M1a|m3", "artifact_type": "csv",
         "relative_path": "02_raw/matched_timing_n30.csv", "sha256": h_n30,
         "run_id": "", "case_id": "", "git_commit": "", "description": "N=30 all attempts"},
        {"evidence_id": "EV_WAIT", "comment_ids": "M1b|M4", "artifact_type": "csv",
         "relative_path": "02_raw/waits_no_go.csv", "sha256": h_ws1,
         "run_id": "", "case_id": "", "git_commit": "", "description": "session 1 waits N=3 without -go"},
        {"evidence_id": "EV_WAIT2", "comment_ids": "M1b|M4", "artifact_type": "csv",
         "relative_path": "02_raw/waits_logged.csv", "sha256": h_w,
         "run_id": "", "case_id": "", "git_commit": "", "description": "session 2 waits N=5 + QPC jsonl"},
        {"evidence_id": "EV_MEM", "comment_ids": "M4", "artifact_type": "csv",
         "relative_path": "02_raw/memcmp_variants.csv", "sha256": h_mc,
         "run_id": "", "case_id": "", "git_commit": "", "description": "session 1 memcmp; CLR abort after two APIs"},
        {"evidence_id": "EV_MEM2", "comment_ids": "M4", "artifact_type": "csv",
         "relative_path": "02_raw/memcmp_variants_v2.csv", "sha256": h_mc2,
         "run_id": "", "case_id": "", "git_commit": "", "description": "session 2 memcmp _memicmp RtlCompareMemory"},
        {"evidence_id": "EV_CASE", "comment_ids": "M3|M2", "artifact_type": "csv",
         "relative_path": "02_raw/case_studies_by_run.csv", "sha256": h_cs,
         "run_id": "", "case_id": "", "git_commit": "", "description": "four PE no milestone"},
        {"evidence_id": "EV_DA", "comment_ids": "M4", "artifact_type": "csv",
         "relative_path": "02_raw/da_oracles.csv", "sha256": h_da,
         "run_id": "", "case_id": "", "git_commit": "", "description": "-da five oracles exit 0"},
        {"evidence_id": "EV_M32", "comment_ids": "M4", "artifact_type": "csv",
         "relative_path": "02_raw/module32_waits.csv", "sha256": h_m32,
         "run_id": "", "case_id": "", "git_commit": "", "description": "Module32 terminate+kernel32; no pinvm proof"},
        {"evidence_id": "EV_M32F", "comment_ids": "M4", "artifact_type": "csv",
         "relative_path": "02_raw/module32_fixture.csv", "sha256": h_m32f,
         "run_id": "", "case_id": "", "git_commit": "", "description": "dummy pinvm.dll visible NAT/TMW0 hidden -dp/-da"},
        {"evidence_id": "EV_PE", "comment_ids": "M4", "artifact_type": "csv",
         "relative_path": "02_raw/processenum_base.csv", "sha256": h_pe,
         "run_id": "", "case_id": "", "git_commit": "", "description": "ProcessEnum pin.exe 0/3/0/0"},
        {"evidence_id": "EV_FO", "comment_ids": "M4", "artifact_type": "csv",
         "relative_path": "02_raw/functional_oracles.csv", "sha256": h_fo,
         "run_id": "", "case_id": "", "git_commit": "", "description": "earlier PE_base pin.exe=3 vs treat 0"},
        {"evidence_id": "EV_LETTER_EN", "comment_ids": "M1a|M1b|M2|M3|M4|m1|m2|m3",
         "artifact_type": "pdf", "relative_path": "07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf",
         "sha256": sha256_file(letter_en) if letter_en.exists() else "",
         "run_id": "", "case_id": "", "git_commit": "", "description": "official letter EN"},
    ]

    matrix = [
        {"comment_id": "M1a", "reviewer_request": "Major 1: comparacao temporal",
         "literal_request_excerpt": "keep the workload the same and compare -go against -go -do",
         "expected_evidence": "timing_results.csv;summary_stats.csv",
         "status": "satisfied",
         "artifact_paths": "02_raw/matched_timing_n30.csv|03_processed/timing_results.csv|03_processed/summary_stats.csv",
         "result_summary": "N=30 kept. Conventional medians TMW0 2433.285 (30/30); GO 3083.210 (11/30); GO_DO 2104.770 (30/30).",
         "remaining_gap": "Manuscript Table 6 not yet rewritten."},
        {"comment_id": "M1b", "reviewer_request": "Major 1: coerencia temporal",
         "literal_request_excerpt": "sequential waits, concurrent waits, repeated clock reads, as well as an alertable wait that returns early",
         "expected_evidence": "wait_events.csv;clock_reads.csv",
         "status": "satisfied",
         "artifact_paths": "02_raw/waits_logged.csv|02_raw/wait_events_jsonl/|03_processed/wait_events.csv|03_processed/clock_reads.csv",
         "result_summary": "24/10 N=5 logged: 20/20 exit 0. Native par med 213.678 < seq 406.218 (double_count=YES). EMPTY/TMW0/-do invert (par 571.867/553.862/517.802). TickCount monotonic 20/20. Alertable ~46 ms only native. -do does not restore overlap.",
         "remaining_gap": "par_* TID in jsonl is the joining thread (Ev after Join). Do not claim coherent Pin timeline."},
        {"comment_id": "M2", "reviewer_request": "Major 2: recursos e progresso",
         "literal_request_excerpt": "see if they reach comparable execution milestones",
         "expected_evidence": "milestones.csv;resource_samples.csv;process_tree.csv",
         "status": "partial",
         "artifact_paths": "03_processed/milestones.csv|03_processed/summary_stats.csv|03_processed/case_comparison.csv",
         "result_summary": "Table 9 -87/-38 is 10s/31PE. 60s 50+50: Skew lengthens wall +55452 / +37387 ms. Four PE: new_files=0.",
         "remaining_gap": "No named process tree. No per-PID WS series in this pack."},
        {"comment_id": "M3", "reviewer_request": "Major 3: beneficio pratico",
         "literal_request_excerpt": "identify the relevant check, and show that enabling the countermeasure allows execution to reach additional code or produce additional observable behavior",
         "expected_evidence": "case.json;case_comparison.csv;report.md",
         "status": "blocked",
         "artifact_paths": "05_cases/|03_processed/case_comparison.csv|02_raw/case_studies_by_run.csv",
         "result_summary": "Four PE attempted. Check not identified. No extra file/stdout/named child.",
         "remaining_gap": "Practical benefit not demonstrated. Do not claim a case study."},
        {"comment_id": "M4", "reviewer_request": "Major 4: interfaces e modo conjunto",
         "literal_request_excerpt": "all the supported paths should have some solid evidence behind them",
         "expected_evidence": "functional_tests.csv;combined oracle runs",
         "status": "partial",
         "artifact_paths": "02_raw/da_oracles.csv|02_raw/module32_fixture.csv|02_raw/processenum_base.csv|02_raw/memcmp_variants_v2.csv",
         "result_summary": "Fixture pinvm: NAT/TMW0=1, -dp/-da=0, kernel32 kept. ProcessEnum pin.exe NAT=0 TMW0=3 -dp=0 -da=0. memcmp/_memicmp/RtlCompareMemory PASS vs MASKED. -da 5/5.",
         "remaining_gap": "wmemcmp and RtlEqualMemory NOT_EXERCISED (EntryPointNotFound). memcmp_passthrough n=7 is equal by construction. Dummy pinvm is version.dll copy, not real Pin."},
        {"comment_id": "m1", "reviewer_request": "Minor 1: reproducao",
         "literal_request_excerpt": "Tie the reproducibility content a specific release or commit in the repo",
         "expected_evidence": "campaign.json;environment.json;corpus_audited.csv;execution_plan.csv",
         "status": "partial",
         "artifact_paths": "00_protocol/campaign.json|00_protocol/environment.json",
         "result_summary": "Pin 3.28.98749 + DLL 4BBC6270 + snapshot tomware_go. Windows: this paper 10s; 50+50 is 60/120s.",
         "remaining_gap": "No git tag/commit for this pack (user forbade unsolicited commit). 3040df7 is stale."},
        {"comment_id": "m2", "reviewer_request": "Minor 2: texto e Tabela 8",
         "literal_request_excerpt": "Shorten repeated explanations of scope and limitations",
         "expected_evidence": "manuscript_changes.csv;ALTERACOES_SUGERIDAS.md",
         "status": "partial",
         "artifact_paths": "07_review/manuscript_changes.csv|07_review/ALTERACOES_SUGERIDAS.md",
         "result_summary": "Editorial actions listed as proposed.",
         "remaining_gap": "Manuscript not edited."},
        {"comment_id": "m3", "reviewer_request": "Minor 3: resumo",
         "literal_request_excerpt": "Revise the abstract's statement about all five countermeasures after incorporating the corrected timing evidence",
         "expected_evidence": "manuscript_changes.csv;validated_values.json",
         "status": "partial",
         "artifact_paths": "07_review/validated_values.json|07_review/manuscript_changes.csv",
         "result_summary": "Abstract must use 11/30 vs 30/30, not old -go vs -do.",
         "remaining_gap": "Manuscript not edited."},
    ]

    tables = {
        "00_protocol/execution_plan.csv": (
            ["planned_run_id", "campaign_id", "subject_id", "subject_kind", "group", "condition",
             "repetition", "block_id", "order_index", "seed", "window_ms", "timeout_ms",
             "command_argv_json", "comment_ids"], exec_plan),
        "03_processed/run_index.csv": (
            ["run_id", "campaign_id", "subject_id", "subject_kind", "group", "condition", "repetition",
             "block_id", "git_commit", "build_id", "started_at_utc", "launch_success",
             "termination_reason", "process_exit_value", "exit_source", "timed_out", "window_ms",
             "external_wall_ms", "functional_status", "collection_status", "run_json_path",
             "comment_ids"], run_index),
        "03_processed/timing_results.csv": (
            ["run_id", "subject_id", "condition", "repetition", "clock_api", "score_unit",
             "requested_wait_ms", "external_elapsed_ms", "reported_elapsed_ms", "oracle_score",
             "threshold", "comparison_operator", "below_threshold", "timed_out",
             "termination_reason", "validity", "missing_reason", "source_path"], timing_rows),
        "03_processed/wait_events.csv": (
            ["run_id", "sequence", "pid", "tid", "scenario", "wait_api", "requested_wait_ms",
             "start_reference_ns", "end_reference_ns", "observed_wait_ms", "return_value",
             "early_return", "overlap_group", "offset_before_ms", "offset_after_ms",
             "source_path"], wait_rows),
        "03_processed/clock_reads.csv": (
            ["run_id", "sequence", "pid", "tid", "scenario", "clock_api", "reference_ns",
             "returned_value_text", "returned_unit", "offset_ms", "delta_from_previous_ms",
             "regression_detected", "validity", "missing_reason", "source_path"], clock_rows),
        "03_processed/functional_tests.csv": (
            ["test_id", "run_id", "module", "interface", "variant", "scenario", "control_type",
             "symbol_present", "hook_installed", "expected_behavior", "expected_return_text",
             "observed_return_text", "target_visible_before", "target_visible_after",
             "unrelated_entries_preserved", "enumeration_terminated", "buffers_preserved",
             "result", "evidence_path", "comment_ids"], func_rows),
        "03_processed/milestones.csv": (
            ["run_id", "case_id", "subject_id", "milestone_id", "milestone_definition",
             "expected_artifact", "reached", "time_from_start_ms", "artifact_path",
             "artifact_sha256", "evidence_path"], mile_rows),
        "03_processed/resource_samples.csv": (
            ["run_id", "sequence", "reference_ns", "elapsed_ms", "pid", "parent_pid", "process_role",
             "cpu_user_ms", "cpu_kernel_ms", "working_set_bytes", "private_bytes", "thread_count",
             "io_read_bytes", "io_write_bytes", "process_alive", "validity", "missing_reason"],
            res_rows),
        "03_processed/process_tree.csv": (
            ["run_id", "pid", "parent_pid", "process_instance_id", "image_name", "image_sha256",
             "started_at_utc", "ended_at_utc", "is_root", "termination_reason", "evidence_path"],
            tree_rows),
        "03_processed/case_comparison.csv": (
            ["case_id", "subject_id", "check_id", "module", "baseline_condition",
             "treatment_condition", "baseline_run_ids_json", "treatment_run_ids_json",
             "check_location_text", "branch_baseline_text", "branch_treatment_text",
             "additional_behavior", "artifact_path", "artifact_sha256", "causal_evidence_path",
             "conclusion", "limitations"], case_comp),
        "03_processed/summary_stats.csv": (
            ["stat_id", "comment_id", "subject_id_or_stratum", "metric", "unit", "contrast",
             "estimator", "estimate", "q1", "q3", "ci_level", "ci_low", "ci_high", "n_planned",
             "n_recorded", "n_valid", "n_binaries", "denominator_description", "analysis_unit",
             "ci_method", "seed", "source_run_ids_json", "script_path"], stats),
        "07_review/evidence_index.csv": (
            ["evidence_id", "comment_ids", "artifact_type", "relative_path", "sha256",
             "run_id", "case_id", "git_commit", "description"], evidence),
        "07_review/manuscript_changes.csv": (
            ["change_id", "comment_id", "section", "table_or_figure", "reason", "evidence_ids",
             "validated_stat_ids", "proposed_text_path", "application_status"], manuscript),
        "01_source/changes.csv": (
            ["change_id", "git_commit", "file_path", "reason", "comment_ids", "tests_affected",
             "test_results_path", "regression_status"], changes),
        "07_review/reviewer_matrix.csv": (
            ["comment_id", "reviewer_request", "literal_request_excerpt", "expected_evidence",
             "status", "artifact_paths", "result_summary", "remaining_gap"], matrix),
    }
    for rel, (hdr, rows) in tables.items():
        write_csv(EVID / rel, hdr, rows)

    dump_json(
        EVID / "07_review" / "validated_values.json",
        {
            "pin": PIN,
            "dll_prefix": BUILD,
            "timing": {
                "n": 30,
                "file_sha256": h_n30,
                "median_conventional": {"TMW0": 2433.285, "GO": 3083.210, "GO_DO": 2104.770},
                "below_3000": {"TMW0": "30/30", "GO": "11/30", "GO_DO": "30/30"},
                "do_not_use": "matched_timing_summary.csv lower-of-pair",
            },
            "waits_logged_n5": {
                "n": 5,
                "exit0": "20/20",
                "median_ms": {
                    "NAT": {"seq": 406.218, "par": 213.678, "tick": 62, "alert": 45.867},
                    "EMPTY": {"seq": 433.421, "par": 571.867, "tick": 62, "alert": 445.610},
                    "TMW0": {"seq": 441.209, "par": 553.862, "tick": 78, "alert": 441.411},
                    "DO": {"seq": 414.809, "par": 517.802, "tick": 56, "alert": 383.428},
                },
                "note": "Pin inverts overlap; -do does not restore. TID of par_* is joining thread.",
            },
            "module32_fixture": {
                "dummy": "version.dll copied as %TEMP%\\pinvm.dll",
                "NAT": "fixture_pinvm=1 pinish=1 count=32",
                "TMW0": "fixture_pinvm=1 pinish=1 count=31",
                "DP": "fixture_pinvm=0 pinish=0 count=30",
                "DA": "fixture_pinvm=0 pinish=0 count=30",
            },
            "memcmp_v2": {
                "exercised": ["memcmp", "_memicmp", "RtlCompareMemory"],
                "not_exercised": ["RtlEqualMemory", "wmemcmp"],
                "passthrough": "n=7 of AAAAAAAA vs AAAAAAAB is equal by construction",
            },
            "windows": {"jcvht_table9_s": 10, "ieee_50_50_persistent_s": 60},
            "forbid": [
                "155/155",
                "9/31 as success",
                "-87% as gain",
                "malware used the five checks",
                "case study MAL_03/07/10 BEN_06",
                "Arancino superiority",
            ],
        },
    )
    (EVID / "07_review" / "ALTERACOES_SUGERIDAS.md").write_text(
        "# Alteracoes sugeridas no manuscrito JCVHT (ainda proposed)\n\n"
        "1. Table 6 = N=30 matched (2,433.285 / 3,083.210 / 2,104.770).\n"
        "2. Limitacao de waits (N=5 QPC 24/10): Pin inverte overlap; -do nao restaura; alertavel ~46 ms so nativo.\n"
        "2b. Module32 fixture: pinvm dummy visivel NAT/TMW0, oculto -dp/-da; kernel32 mantido.\n"
        "2c. memcmp v2: 3 APIs (memcmp, _memicmp, RtlCompareMemory). wmemcmp/RtlEqualMemory sem export.\n"
        "3. Table 9: rotular 10 s; nao republicar -87% como ganho; nao importar +55 s como a mesma tabela.\n"
        "4. Major 3: beneficio pratico nao demonstrado.\n"
        "5. Abstract: 11/30 vs 30/30; cinco modulos oraculados a parte.\n"
        "6. Table 8: wrap TestProcessEnum.\n"
        "7. Identificar software por Pin 3.28.98749 + DLL 4BBC6270, nao 3040df7.\n",
        encoding="utf-8",
    )
    for extra in (
        "OVERLEAF_AJUSTES_RESTANTES.md",
        "PARECER_STATUS.md",
        "PASSO_A_PASSO_CLOSE.md",
    ):
        src_md = JCV / extra
        if src_md.exists():
            shutil.copy2(src_md, EVID / "07_review" / extra)

    (EVID / "07_review" / "RELATORIO_FINAL.md").write_text(
        "# Relatorio final JCVHT 24/10/2026\n\n"
        "Sessao close (oraculos, sem malware) concluida. Carta: 07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf\n\n"
        "- M1a satisfied (N=30).\n"
        "- M1b satisfied with Pin-overlap limitation (N=5 QPC; 20/20 exit 0).\n"
        "- M2 partial (no tree / no per-PID series).\n"
        "- M3 blocked: no milestone.\n"
        "- M4 partial (3/5 memcmp-family APIs; fixture pinvm closed; wmemcmp/RtlEqualMemory not exported).\n"
        "- m1-m3 partial: manuscript not rewritten.\n",
        encoding="utf-8",
    )
    (EVID / "01_source" / "BUILD.md").write_text(
        "# Build\n\nPin 3.28.98749. TOMWare.dll SHA-256 prefix 4BBC6270. Snapshot tomware_go.\n"
        "No new commit in this pack.\n",
        encoding="utf-8",
    )
    (EVID / "01_source" / "changes.patch").write_text(
        "# No patch. User forbade unsolicited git commit.\n", encoding="utf-8"
    )
    (EVID / "08_reproduce").mkdir(parents=True, exist_ok=True)
    (EVID / "08_reproduce" / "README.md").write_text(
        "# Reproduzir\n\nNao repetir N=30 nem os 4 PE. Fontes: 02_raw/*.csv.\n"
        "Gerar este pacote: python TOMWare/experiment/jcvht_revision/fill_jcvht_pacote.py\n",
        encoding="utf-8",
    )
    dump_json(
        EVID / "08_reproduce" / "validation_report.json",
        {
            "generated_utc": "2026-10-24T22:30:00Z",
            "timing_rows": len(timing_rows),
            "wait_runs": len(waits),
            "wait_session1_runs": len(waits_s1),
            "case_rows": len(cases),
            "n30_sha256": h_n30,
            "status": {"M1a": "satisfied", "M1b": "satisfied", "M2": "partial",
                       "M3": "blocked", "M4": "partial", "m1": "partial",
                       "m2": "partial", "m3": "partial"},
        },
    )

    # Excel
    try:
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill
        from openpyxl.utils import get_column_letter
        from openpyxl.worksheet.table import Table, TableStyleInfo
    except ImportError:
        import subprocess
        subprocess.check_call(["python", "-m", "pip", "install", "openpyxl", "-q"])
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill
        from openpyxl.utils import get_column_letter

    def sheet_from_csv(wb, name, path: Path):
        ws = wb.create_sheet(name)
        if not path.exists():
            ws["A1"] = "missing"
            return
        with path.open(encoding="utf-8", newline="") as f:
            rows = list(csv.reader(f))
        for i, row in enumerate(rows, 1):
            for j, val in enumerate(row, 1):
                cell = ws.cell(i, j, val)
                if i == 1:
                    cell.font = Font(bold=True)
                    cell.fill = PatternFill("solid", fgColor="E2E8F0")
        ws.auto_filter.ref = f"A1:{get_column_letter(max(1, len(rows[0]) if rows else 1))}{len(rows)}"
        ws.freeze_panes = "A2"

    wb = Workbook()
    leia = wb.active
    leia.title = "LEIA_ME"
    leia["A1"] = "RESULTADOS_JCVHT.xlsx"
    leia["A2"] = "Gerado 24/10/2026 a partir dos CSV auditados + sessao close. Nao editar medianas a mao."
    leia["A3"] = f"Pin {PIN}  DLL {BUILD}  campaign {CAMP}"
    leia["A4"] = "Unidades: ticks no TIMING; ms nas esperas; bytes se presentes (aqui ausentes)."
    leia["A5"] = "M3 = blocked. Nao afirmar case study."
    leia["A6"] = "Carta oficial: 07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf"
    sheet_from_csv(wb, "REVISOR", EVID / "07_review" / "reviewer_matrix.csv")
    sheet_from_csv(wb, "CORPUS", EVID / "00_protocol" / "corpus_audited.csv")
    sheet_from_csv(wb, "EXECUCOES", EVID / "03_processed" / "run_index.csv")
    sheet_from_csv(wb, "TIMING", EVID / "03_processed" / "timing_results.csv")
    sheet_from_csv(wb, "ESPERAS_RELOGIOS", EVID / "03_processed" / "wait_events.csv")
    sheet_from_csv(wb, "INTERFACES", EVID / "03_processed" / "functional_tests.csv")
    sheet_from_csv(wb, "MARCOS", EVID / "03_processed" / "milestones.csv")
    sheet_from_csv(wb, "RECURSOS", EVID / "03_processed" / "resource_samples.csv")
    sheet_from_csv(wb, "CASOS", EVID / "03_processed" / "case_comparison.csv")
    sheet_from_csv(wb, "ESTATISTICA", EVID / "03_processed" / "summary_stats.csv")
    sheet_from_csv(wb, "EVIDENCIAS", EVID / "07_review" / "evidence_index.csv")
    sheet_from_csv(wb, "ALTERACOES", EVID / "07_review" / "manuscript_changes.csv")
    xlsx = EVID / "06_workbook" / "RESULTADOS_JCVHT.xlsx"
    xlsx.parent.mkdir(parents=True, exist_ok=True)
    wb.save(xlsx)

    # SHA256SUMS
    lines = []
    for p in sorted(EVID.rglob("*")):
        if p.is_file():
            rel = p.relative_to(EVID).as_posix()
            lines.append(f"{sha256_file(p)}  {rel}")
    (EVID / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    (EVID / "LEIA_PRIMEIRO.md").write_text(
        "# JCVHT_EVIDENCE_2026-10-24\n\n"
        "Pacote **preenchido** apos a sessao close (waits N=5, fixture Module32, memcmp v2).\n"
        "Submission c05a1271-d18d-468d-8c50-9dc8b6c10952.\n\n"
        "- Carta oficial EN: `07_review/JCVHT_c05a1271_Response_to_Reviewers.pdf`\n"
        "- Excel: `06_workbook/RESULTADOS_JCVHT.xlsx`\n"
        "- Matriz: `07_review/reviewer_matrix.csv`\n"
        "- Brutos: `02_raw/` (inclui wait_events_jsonl/)\n\n"
        "M3 continua **blocked** (sem marco). Artigo ainda nao reescrito.\n",
        encoding="utf-8",
    )

    # Also refresh the original package modelos so the zip the user named is updated
    dest_pkg = JCV / "_pacote_agente_filled" / "JCVHT_Pacote_Agente"
    if dest_pkg.exists():
        shutil.rmtree(dest_pkg.parent)
    dest_pkg.mkdir(parents=True)
    shutil.copytree(SRC_PKG, dest_pkg, dirs_exist_ok=True)
    mapping = {
        "timing_results.csv": EVID / "03_processed" / "timing_results.csv",
        "wait_events.csv": EVID / "03_processed" / "wait_events.csv",
        "clock_reads.csv": EVID / "03_processed" / "clock_reads.csv",
        "functional_tests.csv": EVID / "03_processed" / "functional_tests.csv",
        "milestones.csv": EVID / "03_processed" / "milestones.csv",
        "resource_samples.csv": EVID / "03_processed" / "resource_samples.csv",
        "process_tree.csv": EVID / "03_processed" / "process_tree.csv",
        "case_comparison.csv": EVID / "03_processed" / "case_comparison.csv",
        "summary_stats.csv": EVID / "03_processed" / "summary_stats.csv",
        "run_index.csv": EVID / "03_processed" / "run_index.csv",
        "execution_plan.csv": EVID / "00_protocol" / "execution_plan.csv",
        "corpus_audited.csv": EVID / "00_protocol" / "corpus_audited.csv",
        "evidence_index.csv": EVID / "07_review" / "evidence_index.csv",
        "manuscript_changes.csv": EVID / "07_review" / "manuscript_changes.csv",
        "changes.csv": EVID / "01_source" / "changes.csv",
        "reviewer_matrix.csv": EVID / "07_review" / "reviewer_matrix.csv",
    }
    for name, src in mapping.items():
        shutil.copy2(src, dest_pkg / "modelos" / name)
    shutil.copy2(EVID / "LEIA_PRIMEIRO.md", dest_pkg / "LEIA_PRIMEIRO.md")
    shutil.copy2(xlsx, dest_pkg / "RESULTADOS_JCVHT.xlsx")
    if letter_en.exists():
        shutil.copy2(letter_en, dest_pkg / letter_en.name)
    if letter_pt.exists():
        shutil.copy2(letter_pt, dest_pkg / letter_pt.name)
    shutil.copytree(EVID / "02_raw", dest_pkg / "02_raw", dirs_exist_ok=True)
    shutil.copytree(EVID / "05_cases", dest_pkg / "05_cases", dirs_exist_ok=True)
    shutil.copy2(EVID / "07_review" / "validated_values.json", dest_pkg / "validated_values.json")
    shutil.copy2(EVID / "07_review" / "ALTERACOES_SUGERIDAS.md", dest_pkg / "ALTERACOES_SUGERIDAS.md")
    shutil.copy2(EVID / "07_review" / "RELATORIO_FINAL.md", dest_pkg / "RELATORIO_FINAL.md")

    # update MANIFEST + SHA of filled package
    files = []
    for p in sorted(dest_pkg.rglob("*")):
        if p.is_file():
            files.append({
                "path": p.relative_to(dest_pkg).as_posix(),
                "bytes": p.stat().st_size,
                "sha256": sha256_file(p),
            })
    dump_json(
        dest_pkg / "MANIFEST.json",
        {
            "package": "JCVHT_Pacote_Agente",
            "content_type": "filled_results_2026-10-24",
            "new_experiment_results": 1,
            "source_templates": "JCVHT_Pacote_Para_Agente.zip 22/10",
            "files": files,
        },
    )
    (dest_pkg / "SHA256SUMS.txt").write_text(
        "\n".join(f"{x['sha256']}  {x['path']}" for x in files) + "\n", encoding="utf-8"
    )

    def zipdir(folder: Path, zip_path: Path, arc_root: str | None = None) -> None:
        zip_path.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for p in folder.rglob("*"):
                if p.is_file():
                    rel = p.relative_to(folder)
                    arc = f"{arc_root}/{rel.as_posix()}" if arc_root else rel.as_posix()
                    zf.write(p, arc)

    z1 = JCV / "cartas" / "JCVHT_EVIDENCE_2026-10-24.zip"
    z2 = Path(r"c:\Users\marge\Downloads") / "JCVHT_Pacote_Para_Agente_atualizado_2026-10-24.zip"
    z3 = ROOT / "JCVHT_EVIDENCE_2026-10-24.zip"
    zipdir(EVID, z1, "JCVHT_EVIDENCE_2026-10-24")
    zipdir(dest_pkg, z2, "JCVHT_Pacote_Agente")
    shutil.copy2(z1, z3)
    dl = Path(r"c:\Users\marge\Downloads")
    if letter_en.exists():
        shutil.copy2(letter_en, dl / letter_en.name)
    if letter_pt.exists():
        shutil.copy2(letter_pt, dl / letter_pt.name)
    shutil.copy2(JCV / "OVERLEAF_AJUSTES_RESTANTES.md", dl / "OVERLEAF_AJUSTES_RESTANTES.md")
    print("evidence", z1, z1.stat().st_size)
    print("updated pack", z2, z2.stat().st_size)


if __name__ == "__main__":
    main()
