# -*- coding: utf-8 -*-
"""Ingest access_m3_cases (3 SHA x TMW0/TMW_DP/TMW_DO). Never sets identified=true."""
from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias\TOMWare")
ORACLE = ROOT / "experiment" / "results" / "oracles"
MS = ROOT / "experiment" / "validation" / "manuscript" / "ieee_access_ressubmissao"
DOWNLOADS = Path(r"C:\Users\marge\Downloads")
EXPECTED_PIN = "920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819"
DLL = "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6"
SAMPLES = ("MAL_08", "MAL_13", "MAL_07")
MODES = ("TMW0", "TMW_DP", "TMW_DO")
PIN_TREE = {"pin.exe", "pinbin.exe", "conhost.exe", "?"}


def find_dir(name: str) -> Path | None:
    for base in (DOWNLOADS / name, ORACLE / name, ORACLE / "guest" / name):
        if base.is_dir() and any(base.rglob("run_meta.json")):
            return base
    return None


def copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def load_runs(d: Path) -> list[dict]:
    rows = []
    for meta in sorted(d.glob("*/run_meta.json")):
        data = json.loads(meta.read_text(encoding="utf-8-sig"))
        data["run_dir"] = meta.parent.name
        stdout = (meta.parent / "stdout.txt").read_text(encoding="utf-8", errors="replace")
        stderr = (meta.parent / "stderr.txt").read_text(encoding="utf-8", errors="replace")
        blob = stdout + "\n" + stderr
        data["dll_map_failed"] = ("Failure to map DLL" in blob) or ("System error 216" in blob)
        if data["dll_map_failed"]:
            data["validity_note"] = "pin_failed_to_map_dll_win32_216"
        rows.append(data)
    return rows


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def as_int(v, default=0) -> int:
    try:
        if v is None or v == "":
            return default
        return int(v)
    except (TypeError, ValueError):
        return default


def pair_note(base: dict | None, treat: dict | None) -> dict:
    out = {
        "hook_seen": False,
        "result_changed": False,
        "extra_vs_tmw0": False,
        "chain_complete": False,
        "extra_why": "missing_arm",
    }
    if not treat:
        return out
    out["hook_seen"] = bool(treat.get("hook_seen"))
    out["result_changed"] = bool(treat.get("result_changed"))
    if not base:
        out["extra_why"] = "no_tmw0"
        return out
    extra_files = as_int(treat.get("n_new_files")) > as_int(base.get("n_new_files"))
    extra_reg = as_int(treat.get("n_registry_delta")) > as_int(base.get("n_registry_delta"))
    extra_app = as_int(treat.get("n_app_descendants")) > as_int(base.get("n_app_descendants"))
    extra_tcp = as_int(treat.get("n_tcp_established")) > as_int(base.get("n_tcp_established"))
    bits = []
    if extra_files:
        bits.append("files")
    if extra_reg:
        bits.append("registry")
    if extra_app:
        bits.append("app_child")
    if extra_tcp:
        bits.append("tcp")
    out["extra_vs_tmw0"] = bool(bits)
    out["extra_why"] = "|".join(bits) if bits else "no_extra_vs_tmw0"
    out["chain_complete"] = bool(out["hook_seen"] and out["result_changed"] and out["extra_vs_tmw0"])
    return out


def render_awaiting() -> str:
    return """# Item-by-item response — Access (chain 1–3 still without guest)

Do not send to IEEE. This is not the double-blind supplement. No malware. Not the 9,000.
Citation: git a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3. DLL 4BBC6270. Pin launcher 920A730A.

**Items 1–3: protocol ready, evidence not yet ingested.**
Expected folder on the host: `C:\\Users\\marge\\Downloads\\access_m3_cases`
After copying, run `ingest_m3_cases.py`. Until then, `identified=false`.

## 1. Relate malware, check, and countermeasure

**Not yet demonstrated at runtime.** In the 9,000, `-mc` was off. IAT/strings in `identify_summary.csv` are not an executed branch.

A priori protocol (do not add samples):
| Sample | SHA-256 | IAT lead (not a case) | Arms |
|---|---|---|---|
| MAL_08 | 1693df9d…417b6d38 | Toolhelp + timing | TMW0 / TMW_DP / TMW_DO |
| MAL_13 | 2a2b6b75…ebb9e24 | Toolhelp + timing | TMW0 / TMW_DP / TMW_DO |
| MAL_07 | 153e1147…19800d | SleepEx / QPC / IsDebuggerPresent | TMW0 / TMW_DP / TMW_DO |

N=1, 60 s, DLL 4BBC6270, launcher `pin\\pin.exe` 920A730A, `-mc` on, network off, restore `tomware_go` between modes.
TMW0 (`-q -mc`) does not install the `-dp`/`-do` hooks; “called the check” can appear only under TMW_DP or TMW_DO.

This does **not** authorize writing that the 100 executables use the five checks.

## 2. Additional behavior in selected cases

**Not yet demonstrated.** r43d is benign (BEN_28/46/47) and `behavioral_progress_observed=false`. Alive at 60 s does not count.

The guest compares TMW0 with the knob and records hashed files (0 bytes = empty field), Run/RunOnce delta, children that are not pin/conhost, established TCP (should be 0 with network off).
A case only if: hook + result changed + extra **versus TMW0** on the same PE. Without all three, `identified` stays false.

## 3. Explain SkewMask behaviorally

**Not yet demonstrated on malware.** Table 25/r43d does not answer this.

TMW_DO arm (`-do -q -mc`) on the three SHA. Read `sleep_calls_intercepted`, `time_queries_intercepted`, `corrections_applied`, duration, tree, hashes, children.
Longer duration under `-do` is cost/wait until there is extra artifact versus TMW0. With no time calls, item 3 stays: “SkewMask was not triggered on these samples”.

## 4. SkewMask temporal coherence

**Not run. Limitation.** Timeouts under Pin on concurrent/overlapping/alertable waits remain inconclusive. Do not change `SkewMask.cpp` (invalidates Table 6 / N=30). Do not copy JCVHT cells (TickCount 4/10, SleepEx 0/10).

## 5. Pin without Pintool on the corpus

**Not a corpus arm.** Only the technical guest N=3 control on `TestAntiDebug.exe` exists (launcher 920A730A, 3/3 exit 0, 1900–2963 ms). That shows the launcher works; it does not give duration/resources/outcomes on the 100 PE. May remain a limitation. `campaign.json` `pin_condition_valid=false` was not inverted.

## 6. Incomplete metadata

**Limitation already declared.** `corpus.csv`: family `Trojan_Bazaar` / `Backdoor_Bazaar` (MalwareBazaar label, not a VirusTotal family); packer/protector `unknown` on the 50 MAL; `targeted_evasion=unverified`. The three SHA of this protocol do not change that until the technique is empirically verified **at runtime**.

## 7. External experimental comparison

**Limitation / future work.** Arancino, COBAI, and Peekaboo were not executed. Arancino requires Pin 2.14 and is 32-bit; the Access corpus is 100% x64. The current comparison is conceptual.

## 8. Prospective eligibility criteria

**Limitation already conceded.** The criteria were explained and are independent of result direction, but collection of the 9,000 was post hoc. This protocol **fixes the three SHA and the arms before the run**. It does not replace a corpus confirmation campaign.

## What is already addressed (do not repeat)

Paired AntiDebug; SkewMask fixed-N 90 attempts; CIs; 100 PE corpus; 9,000; Module32 (oracle); comparison routines; combined mode; references; typography; Figure 1; moderated conclusions; technical pin-bare N=3; r43d trees (benign); 22/30 correction.

## Forbidden phrases in this close-out

- “the 100 executables use the five checks”
- IAT of MAL_08/13/07 = executed check
- TMW_DO / TMW_DP alive at 60 s = recovered behavior
- pin → sample + conhost tree = progress
- r43d / BEN_28/46/47 as a malware case
- `identified=true` without the four links
- Arancino bake-off
"""


def render_from_runs(rows: list[dict]) -> str:
    by = {(r.get("sample_id"), r.get("mode")): r for r in rows}
    lines = [
        "# Item-by-item response — Access after ingesting access_m3_cases",
        "",
        "Do not send to IEEE. This is not the double-blind supplement. No malware. Not the 9,000.",
        "Citation: git a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3. DLL 4BBC6270. Pin launcher 920A730A.",
        "",
        f"Ingested runs: {len(rows)}. `identified=false` on all of them (ingest does not promote a case).",
        "",
        "## 1. Relate malware, check, and countermeasure",
        "",
        "| Sample | Mode | hook_seen | module (counts) | result_changed | verdict |",
        "|---|---|---|---|---|---|",
    ]
    any_hook = False
    for sid in SAMPLES:
        for mode in MODES:
            r = by.get((sid, mode))
            if not r:
                lines.append(f"| {sid} | {mode} | missing | — | — | missing |")
                continue
            if r.get("dll_map_failed"):
                lines.append(
                    f"| {sid} | {mode} | inconclusive | Pin failed to map DLL (Win32 216) | {r.get('result_changed')} | INVALID_DLL_MAP |"
                )
                continue
            bits = []
            if as_int(r.get("pe_calls_intercepted")):
                bits.append(f"ProcessEnum calls={r.get('pe_calls_intercepted')} filt={r.get('pe_processes_filtered')}")
            if as_int(r.get("pe_modules_examined")):
                bits.append(f"Module32 exam={r.get('pe_modules_examined')} filt={r.get('pe_modules_filtered')}")
            if as_int(r.get("sleep_calls_intercepted")) or as_int(r.get("time_queries_intercepted")):
                bits.append(
                    f"SkewMask sleep={r.get('sleep_calls_intercepted')} qpc={r.get('time_queries_intercepted')} corr={r.get('corrections_applied')}"
                )
            if as_int(r.get("memcmp_intercepted")):
                bits.append(f"Memcmp {r.get('memcmp_intercepted')}")
            mod = "; ".join(bits) if bits else "no counter > 0"
            if r.get("hook_seen"):
                any_hook = True
            lines.append(
                f"| {sid} | {mode} | {r.get('hook_seen')} | {mod} | {r.get('result_changed')} | {r.get('verdict')} |"
            )
    if not any_hook:
        lines.append("")
        lines.append(
            "**Result:** no valid hook in TMW_DP/TMW_DO so far. "
            "A cell with a DLL map failure (Win32 216) is inconclusive, not proof that the sample did not call the API. "
            "IAT is still not an executed branch. Do not add samples. "
            "Do not write that the 100 use the five checks."
        )
    else:
        lines.append("")
        lines.append(
            "A runtime hook is the only ‘used the check’. TMW0 with counters at zero is expected "
            "(-dp/-do hooks not installed). It remains forbidden to generalize to the 100 PE."
        )

    lines += ["", "## 2. Additional behavior in selected cases", ""]
    lines.append("| Sample | Knob | extra vs TMW0 | chain complete | note |")
    lines.append("|---|---|---|---|---|")
    any_chain = False
    for sid in SAMPLES:
        base = by.get((sid, "TMW0"))
        for mode in ("TMW_DP", "TMW_DO"):
            p = pair_note(base, by.get((sid, mode)))
            if p["chain_complete"]:
                any_chain = True
            lines.append(
                f"| {sid} | {mode} | {p['extra_vs_tmw0']} | {p['chain_complete']} | {p['extra_why']} |"
            )
    lines.append("")
    if any_chain:
        lines.append(
            "**Chain candidate** (hook + change + extra vs TMW0). "
            "`identified` stays false until human review of the artifact (not pin/conhost). "
            "Does not rewrite the 9,000."
        )
    else:
        lines.append(
            "**No complete chain.** Persistence, pin→sample+conhost tree, and alive at 60 s "
            "are not additional behavior. Item 2 remains open / negative."
        )

    lines += ["", "## 3. Explain SkewMask behaviorally", ""]
    lines.append("| Sample | TMW0 ms | TMW_DO ms | sleep | time | corrections | extra vs TMW0 | reading |")
    lines.append("|---|---|---|---|---|---|---|---|")
    skew_fired = False
    for sid in SAMPLES:
        a = by.get((sid, "TMW0")) or {}
        b = by.get((sid, "TMW_DO")) or {}
        p = pair_note(a, b)
        sleep = as_int(b.get("sleep_calls_intercepted"))
        tq = as_int(b.get("time_queries_intercepted"))
        corr = as_int(b.get("corrections_applied"))
        if sleep or tq:
            skew_fired = True
        if as_int(b.get("json_ok")) == 0 and b:
            read = "module_events.json missing; alive at 60 s is not progress; counters not demonstrated"
        elif sleep or tq:
            read = "SkewMask triggered; extra duration is progress only if extra_vs_tmw0"
        else:
            read = "SkewMask not triggered; extra duration = wait/cost"
        lines.append(
            f"| {sid} | {a.get('elapsed_ms', '')} | {b.get('elapsed_ms', '')} | {sleep} | {tq} | {corr} | {p['extra_vs_tmw0']} | {read} |"
        )
    lines.append("")
    if not skew_fired:
        lines.append(
            "**Item 3:** on these three samples SkewMask did not intercept Sleep/QPC. "
            "Do not interpret a longer TMW_DO as progress. r43d (benign) remains separate."
        )
    else:
        lines.append(
            "There was a timing interception. Compare artifacts from the item 2 table; "
            "without extra vs TMW0 the longer duration remains wait/cost."
        )

    lines += [
        "",
        "## 4. SkewMask temporal coherence",
        "",
        "**Not run. Limitation.** This protocol does not replace the concurrent/overlapping/alertable wait battery. `SkewMask.cpp` was not changed.",
        "",
        "## 5. Pin without Pintool on the corpus",
        "",
        "**Limitation.** Only the technical N=3 on TestAntiDebug exists (920A730A, 3/3 exit 0). It is not an arm of the 100 PE.",
        "",
        "## 6. Incomplete metadata",
        "",
        "**Limitation.** Coarse MalwareBazaar family; packer unknown; targeted_evasion=unverified on the 50 MAL.",
        "",
        "## 7. External experimental comparison",
        "",
        "**Limitation.** No Arancino/COBAI/Peekaboo bake-off. Arancino: Pin 2.14, 32-bit vs x64 corpus.",
        "",
        "## 8. Prospective criteria",
        "",
        "The three SHA and the arms were fixed **before** this run. That does not make the 9,000 campaign prospective.",
        "",
        "## Phrases that remain forbidden",
        "",
        "- the 100 use the five checks; IAT = check; alive 60 s = gain; pin+conhost = progress; identified=true without the four links.",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    src = find_dir("access_m3_cases")
    dst = ORACLE / "access_m3_cases"
    out_md = MS / "RESPOSTA_ITENS_1_8_M3.md"
    if not src:
        out_md.write_text(render_awaiting(), encoding="utf-8")
        print("AWAITING guest folder access_m3_cases")
        print(out_md)
        return
    copy_tree(src, dst)
    rows = load_runs(dst)
    fields = [
        "run_dir", "sample_id", "sha256", "mode", "knobs", "pin_sha256",
        "pin_sha256_matches_campaign", "dll_sha256", "elapsed_ms", "exit_code",
        "timed_out", "json_ok", "hook_seen", "result_changed", "verdict",
        "pe_calls_intercepted", "pe_processes_filtered", "pe_modules_examined",
        "pe_modules_filtered", "sleep_calls_intercepted", "time_queries_intercepted",
        "corrections_applied", "n_new_files", "n_registry_delta", "n_tcp_established",
        "n_app_descendants", "app_descendant_names", "stdout_sha256", "stderr_sha256",
        "identified", "chain_complete", "dll_map_failed", "why",
    ]
    write_csv(ORACLE / "access_m3_cases_summary.csv", rows, fields)
    pairs = []
    by = {(r.get("sample_id"), r.get("mode")): r for r in rows}
    for sid in SAMPLES:
        base = by.get((sid, "TMW0"))
        for mode in ("TMW_DP", "TMW_DO"):
            treat = by.get((sid, mode))
            p = pair_note(base, treat)
            pairs.append({
                "sample_id": sid,
                "mode": mode,
                "hook_seen": p["hook_seen"],
                "result_changed": p["result_changed"],
                "extra_vs_tmw0": p["extra_vs_tmw0"],
                "chain_complete": p["chain_complete"],
                "extra_why": p["extra_why"],
                "identified": False,
            })
    write_csv(
        ORACLE / "access_m3_cases_pairs.csv",
        pairs,
        ["sample_id", "mode", "hook_seen", "result_changed", "extra_vs_tmw0", "chain_complete", "extra_why", "identified"],
    )
    manifest = {
        "pack": "access_m3_cases",
        "cited_commit": "a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3",
        "dll": DLL,
        "pin_launcher": EXPECTED_PIN,
        "n_runs": len(rows),
        "identified_true": 0,
        "any_chain_complete": any(p["chain_complete"] for p in pairs),
        "contains_malware": False,
        "not_a_claim": "three_samples_are_not_the_100; IAT_is_not_a_case; alive_is_not_progress",
    }
    (ORACLE / "m3_cases_ingest_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    out_md.write_text(render_from_runs(rows), encoding="utf-8")
    print(f"ingested {len(rows)} runs -> {dst}")
    print(out_md)


if __name__ == "__main__":
    main()
