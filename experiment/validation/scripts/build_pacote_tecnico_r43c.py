# -*- coding: utf-8 -*-
"""Technical-only Access pack: r43c + commit check + protocols. Not IEEE. No article/letter."""
from __future__ import annotations

import csv
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias\TOMWare")
ORACLE = ROOT / "experiment" / "results" / "oracles"
R43C = ORACLE / "access_r43c"
MS = ROOT / "experiment" / "validation" / "manuscript" / "ieee_access_ressubmissao"
SCRIPTS = ROOT / "experiment" / "validation" / "scripts"
PACK_NAME = "Access-2026-38745_EVIDENCIAS_TECNICAS_2026-10-31"
DST = Path(r"C:\Users\marge\Downloads") / PACK_NAME


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def copy_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def named_from_events(run_dir: Path) -> tuple[int, str]:
    ev = run_dir / "process_events.jsonl"
    names = set()
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
        last = " | ".join(tree.read_text(encoding="utf-8", errors="replace").splitlines()[:4])
    return len(names), last


def build_summary() -> list[dict]:
    rows = []
    for meta in sorted(R43C.glob("*/run_meta.json")):
        data = json.loads(meta.read_text(encoding="utf-8"))
        n_named_ever, last_tree = named_from_events(meta.parent)
        data["run_dir"] = meta.parent.name
        data["n_named_distinct_during_run"] = n_named_ever
        data["last_tree_excerpt"] = last_tree
        data["run_meta_sha256"] = sha256(meta)
        rows.append(data)
    fields = [
        "sample_id", "rep", "mode", "sha256", "progress", "validity",
        "timed_out", "process_stayed_alive_60s", "behavioral_progress_observed",
        "exit_code", "elapsed_ms", "peak_ws", "n_named_last_sample",
        "n_named_distinct_during_run", "elevated", "pin_sha256",
        "pin_sha256_matches_campaign", "dll_sha256", "script_rev",
        "first_sample_ms", "sample_ms", "identified", "last_tree_excerpt",
        "run_dir", "run_meta_sha256",
    ]
    out = R43C / "summary.csv"
    with out.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)
    return rows


def main() -> None:
    rows = build_summary()
    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)

    copy_file(MS / "RELATORIO_TECNICO_ITENS_1_3.md", DST / "00_RELATORIO.md")
    copy_file(MS / "STATUS_ITENS_TECNICOS.md", DST / "STATUS_ITENS_TECNICOS.md")
    copy_file(SCRIPTS / "PASSO_A_PASSO_ACCESS_R43C_PINBARE.txt", DST / "PROTOCOLO.txt")
    copy_file(SCRIPTS / "Run-AccessR43c.ps1", DST / "scripts" / "Run-AccessR43c.ps1")
    copy_file(SCRIPTS / "Run-AccessPinBareGuestN3.ps1", DST / "scripts" / "Run-AccessPinBareGuestN3.ps1")
    copy_file(ORACLE / "commit_public_check.json", DST / "commit_public_check.json")
    copy_file(R43C / "summary.csv", DST / "r43c_process_tree" / "summary.csv")
    copy_file(R43C / "README.txt", DST / "r43c_process_tree" / "README.txt")

    for d in sorted(R43C.iterdir()):
        if d.is_dir() and d.name.startswith("BEN_"):
            shutil.copytree(d, DST / "r43c_process_tree" / d.name)

    pin_n3 = ORACLE / "guest" / "pin_bare_guest_n3"
    if pin_n3.exists():
        shutil.copytree(pin_n3, DST / "pin_bare_guest_n3")
    else:
        (DST / "pin_bare_guest_n3_MISSING.txt").write_text(
            "Guest N=3 pin.exe -- TestAntiDebug.exe was not copied to the host.\n"
            "Incompatibility of campaign Pin-without-Pintool is NOT confirmed.\n"
            "Host pin FBA632E4 is pin\\intel64\\bin\\pin.exe (also used by r43c),\n"
            "not proof that Pin-without-tool is unsupported. Do not use host StartServer\n"
            "as the 9,000 campaign decision.\n",
            encoding="utf-8",
        )
        copy_file(ORACLE / "guest" / "pin_probe.csv", DST / "historico" / "pin_probe.csv")
        copy_file(ORACLE / "guest" / "pin_probe_bare.txt", DST / "historico" / "pin_probe_bare.txt")

    n_alive = sum(1 for r in rows if r.get("process_stayed_alive_60s") in (True, "True", "true"))
    n_named_last = sum(1 for r in rows if int(r.get("n_named_last_sample") or 0) > 0)
    ident = {
        "pack": PACK_NAME,
        "for": "collaborator technical evidence — NOT IEEE — NOT the article/letter",
        "campaign_id": "access_r43c_process_tree",
        "n_runs": len(rows),
        "n_still_alive_60s": n_alive,
        "n_named_last_sample": n_named_last,
        "pin_used_intel64": "FBA632E40F00FEEC1FAA7BC1A3BF8CC9A551AB1F17ABA6B07D31C67E602A741A",
        "pin_documented_campaign": "920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819",
        "dll": "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6",
        "script_rev": "r43c.1",
        "identified": False,
        "behavioral_progress_observed": False,
        "pin_bare_n3": pin_n3.exists(),
        "commit_665aebb_public": False,
        "contains_malware": False,
        "contains_article_or_letter": False,
        "not_executed": [
            "full temporal coherence",
            "interface matrix / new DLL vs 9000",
            "paired behavioural traces",
            "malware check-branch-recovered-behavior case",
            "Arancino/COBAI/Peekaboo bake-off",
            "pin_bare_guest_n3 (not copied)",
        ],
    }
    (DST / "MANIFEST.json").write_text(json.dumps(ident, indent=2) + "\n", encoding="utf-8")

    sums = []
    for p in sorted(DST.rglob("*")):
        if p.is_file() and p.name != "SHA256SUMS.txt":
            sums.append(f"{sha256(p)}  {p.relative_to(DST).as_posix()}")
    (DST / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")

    zip_path = Path(r"C:\Users\marge\Downloads") / f"{PACK_NAME}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(DST.rglob("*")):
            if p.is_file():
                z.write(p, arcname=str(Path(PACK_NAME) / p.relative_to(DST)))
    print("ZIP", zip_path, zip_path.stat().st_size)
    print("RUNS", len(rows), "ALIVE60", n_alive, "NAMED_LAST", n_named_last)
    print("FILES", len(sums))


if __name__ == "__main__":
    main()
