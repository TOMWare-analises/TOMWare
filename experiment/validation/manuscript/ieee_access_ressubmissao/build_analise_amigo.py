# -*- coding: utf-8 -*-
"""Monta o zip do colaborador Access. Nao envia a IEEE. Sem malware."""
from __future__ import annotations

import csv
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias\TOMWare")
SRC_R43 = Path(r"C:\Users\marge\Downloads\access_r43")
PACK_NAME = "Access-2026-38745_ANALISE_AMIGO_2026-10-29"
DST = Path(r"C:\Users\marge\Downloads") / PACK_NAME
ORACLE_DST = ROOT / "experiment" / "results" / "oracles" / "access_r43"
MS = ROOT / "experiment" / "validation" / "manuscript" / "ieee_access_ressubmissao"


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def copy_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def copy_dir(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def main() -> None:
    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)

    # 0. textos desta pasta
    for name in (
        "00_LEIA.txt",
        "01_RESPOSTA_ITENS.md",
        "02_MATRIZ_SEIS_REVISORES.csv",
        "03_R43_LEITURA.md",
        "FRASES_PROIBIDAS.txt",
        "RELATORIO_SEIS_REVISORES.md",
        "MATRIZ_SEIS_REVISORES.csv",
        "Access-2026-38745_CURRENT.pdf",
    ):
        src = MS / name
        if name == "02_MATRIZ_SEIS_REVISORES.csv":
            src = MS / "MATRIZ_SEIS_REVISORES.csv"
        if src.exists():
            copy_file(src, DST / name)

    # cartas
    cartas = DST / "cartas"
    for pdf in (
        ROOT / "experiment" / "validation" / "manuscript" / "Access-2026-38745_Response_to_Reviewers.pdf",
        ROOT / "experiment" / "validation" / "manuscript" / "Access-2026-38745_Resposta_aos_Revisores.pdf",
        ROOT / "experiment" / "validation" / "manuscript" / "Access-2026-38745_Overleaf_Instructions.pdf",
    ):
        if pdf.exists():
            copy_file(pdf, cartas / pdf.name)

    # R4.3 runs
    r43_pack = DST / "r43_skewmask_diag"
    copy_dir(SRC_R43, r43_pack)
    copy_dir(SRC_R43, ORACLE_DST)

    rows = []
    for meta in sorted(r43_pack.glob("*/run_meta.json")):
        data = json.loads(meta.read_text(encoding="utf-8"))
        data["run_dir"] = meta.parent.name
        data["run_meta_sha256"] = sha256(meta)
        rows.append(data)
    fieldnames = [
        "sample_id",
        "sha256",
        "mode",
        "knobs",
        "progress",
        "timed_out",
        "exit_code",
        "elapsed_ms",
        "peak_ws",
        "window_sec",
        "dll_sha256",
        "campaign_id",
        "identified",
        "not_a_claim",
        "run_dir",
        "run_meta_sha256",
    ]
    with (r43_pack / "summary.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)

    # evidencias
    ev = DST / "evidencias"
    copies = [
        ROOT / "experiment" / "results" / "campaign" / "corpus_aligned_10k" / "completeness.json",
        ROOT / "experiment" / "results" / "campaign" / "corpus_aligned_10k" / "outcomes_by_stratum.csv",
        ROOT / "experiment" / "results" / "campaign" / "corpus_aligned_10k" / "sample_condition_medians.csv",
        ROOT / "experiment" / "results" / "oracles" / "guest" / "antidebug_n3.csv",
        ROOT / "experiment" / "results" / "oracles" / "matched_timing_n30.csv",
        ROOT / "experiment" / "results" / "oracles" / "matched_timing_summary_conventional.csv",
        ROOT / "experiment" / "results" / "oracles" / "da_n10.csv",
        ROOT / "experiment" / "results" / "oracles" / "processenum_base.csv",
        ROOT / "experiment" / "results" / "oracles" / "module32_fixture.csv",
        ROOT / "experiment" / "results" / "oracles" / "memcmp_n10.csv",
        ROOT / "experiment" / "results" / "oracles" / "arancino" / "BLOQUEIO.md",
        ROOT / "experiment" / "results" / "oracles" / "identify_summary.csv",
        ROOT / "experiment" / "corpus" / "corpus.csv",
        ROOT / "experiment" / "protocol" / "empty_tool_and_pin_probe.md",
        ROOT / "experiment" / "validation" / "manuscript" / "notes" / "campaign_audit_report.md",
        ROOT / "experiment" / "validation" / "manuscript" / "notes" / "exitcode_report.md",
        ROOT / "experiment" / "validation" / "manuscript" / "notes" / "fidelity_report.md",
    ]
    for src in copies:
        if src.exists():
            copy_file(src, ev / src.name)

    # recorte dos tres persistentes
    med_src = ROOT / "experiment" / "results" / "campaign" / "corpus_aligned_10k" / "sample_condition_medians.csv"
    med_dst = ev / "sample_condition_medians_BEN_28_46_47.csv"
    with med_src.open(encoding="utf-8") as f_in, med_dst.open("w", encoding="utf-8", newline="") as f_out:
        r = csv.reader(f_in)
        w = csv.writer(f_out)
        header = next(r)
        w.writerow(header)
        for row in r:
            if row and row[0] in {"BEN_28", "BEN_46", "BEN_47"}:
                w.writerow(row)

    # scripts
    scripts = DST / "scripts"
    copy_file(ROOT / "experiment" / "validation" / "scripts" / "Run-AccessR43.ps1", scripts / "Run-AccessR43.ps1")
    copy_file(
        ROOT / "experiment" / "validation" / "scripts" / "PASSO_A_PASSO_ACCESS_R43.txt",
        scripts / "PASSO_A_PASSO_ACCESS_R43.txt",
    )
    copy_file(ROOT / "experiment" / "scripts" / "runner" / "Invoke-SingleRun.ps1", scripts / "Invoke-SingleRun.ps1")

    ident = {
        "pack": PACK_NAME,
        "for": "collaborator analysis — NOT IEEE submission",
        "campaign_article": "corpus_aligned_10k 100x9x10=9000",
        "dll_sha256": "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6",
        "pin": "3.28.98749",
        "snapshot": "tomware_go",
        "seed": 705851366,
        "git_head": "e382a6c3fb871e802ae33f4cb623f0745d40abc2",
        "r43_campaign_id": "access_r43_skewmask_diag",
        "r43_n_runs": len(rows),
        "contains_malware": False,
        "contains_9000_raw_json": False,
        "not_a_claim": "alive_is_not_progress; not Arancino; not the 9000",
    }
    (DST / "MANIFEST.json").write_text(json.dumps(ident, indent=2) + "\n", encoding="utf-8")

    sums = []
    for p in sorted(DST.rglob("*")):
        if p.is_file() and p.name != "SHA256SUMS.txt":
            rel = p.relative_to(DST).as_posix()
            sums.append(f"{sha256(p)}  {rel}")
    (DST / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")

    zip_path = Path(r"C:\Users\marge\Downloads") / f"{PACK_NAME}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(DST.rglob("*")):
            if p.is_file():
                z.write(p, arcname=str(Path(PACK_NAME) / p.relative_to(DST)))

    print("PACK", DST)
    print("ZIP", zip_path, zip_path.stat().st_size)
    print("RUNS", len(rows))
    print("FILES", len(sums))


if __name__ == "__main__":
    main()
