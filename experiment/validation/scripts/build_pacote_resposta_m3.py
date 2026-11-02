# -*- coding: utf-8 -*-
"""Resposta-pack Access: 8 itens com access_m3_cases. Nao IEEE. Sem malware."""
from __future__ import annotations

import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias\TOMWare")
ORACLE = ROOT / "experiment" / "results" / "oracles"
MS = ROOT / "experiment" / "validation" / "manuscript" / "ieee_access_ressubmissao"
SCRIPTS = ROOT / "experiment" / "validation" / "scripts"
PACK_NAME = "Access-2026-38745_RESPOSTA_ITENS_2026-11-01"
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


def main() -> None:
    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)

    copy_file(MS / "00_RESPOSTA_ITENS_1_8.txt", DST / "00_RESPOSTA.txt")
    copy_file(MS / "RESPOSTA_ITENS_1_8_M3.md", DST / "RESPOSTA_ITENS_1_8_M3.md")
    copy_file(MS / "FRASES_PROIBIDAS.txt", DST / "FRASES_PROIBIDAS.txt")
    copy_file(MS / "STATUS_ITENS_TECNICOS.md", DST / "STATUS_ITENS_TECNICOS.md")
    copy_file(MS / "REPRODUCIBILITY.txt", DST / "REPRODUCIBILITY.txt")
    copy_file(SCRIPTS / "PASSO_A_PASSO_ACCESS_M3_CASES.txt", DST / "PROTOCOLO.txt")
    copy_file(SCRIPTS / "Run-AccessM3Cases.ps1", DST / "Run-AccessM3Cases.ps1")

    raw = ORACLE / "access_m3_cases"
    if not raw.is_dir():
        raise SystemExit("missing access_m3_cases")
    shutil.copytree(raw, DST / "3_casos_m3")

    csv_dir = DST / "csv"
    for src in (
        ORACLE / "access_m3_cases_summary.csv",
        ORACLE / "access_m3_cases_pairs.csv",
        ORACLE / "m3_cases_ingest_manifest.json",
    ):
        copy_file(src, csv_dir / src.name)

    ident = json.loads((ORACLE / "m3_cases_ingest_manifest.json").read_text(encoding="utf-8"))
    ident["pack"] = PACK_NAME
    ident["for"] = "response to items 1-8 with m3 cases — NOT IEEE — not the full article"
    ident["n_runs"] = 9
    ident["identified_true"] = 0
    ident["any_chain_complete"] = False
    ident["n_9000_rerun"] = False
    ident["contains_malware"] = False
    ident["limitations_not_run"] = [
        "full temporal coherence",
        "Pin-without-tool on the 100-PE corpus",
        "complete malware family/packer/evasion metadata",
        "Arancino/COBAI/Peekaboo bake-off",
        "prospective re-collection of the 9,000",
    ]
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
    print("FILES", len(sums))


if __name__ == "__main__":
    main()
