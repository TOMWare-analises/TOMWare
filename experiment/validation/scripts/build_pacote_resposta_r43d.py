# -*- coding: utf-8 -*-
"""Access response pack: prompt items 1–3. Not IEEE. No malware. Not the full article."""
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
PACK_NAME = "Access-2026-38745_RESPOSTA_PENDENCIAS_2026-10-31"
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

    copy_file(MS / "00_RESPOSTA_PENDENCIAS.txt", DST / "00_RESPOSTA.txt")
    copy_file(MS / "RELATORIO_PENDENCIAS_R43D.md", DST / "RELATORIO_PENDENCIAS_R43D.md")
    copy_file(MS / "TABELAS_25_26_27_R43D.md", DST / "TABELAS_25_26_27_R43D.md")
    copy_file(MS / "CORRECAO_22_30.md", DST / "CORRECAO_22_30.md")
    copy_file(MS / "INSERCOES_FINAIS_EN.md", DST / "INSERCOES_FINAIS_EN.md")
    copy_file(MS / "FRASES_PROIBIDAS.txt", DST / "FRASES_PROIBIDAS.txt")
    copy_file(MS / "REPRODUCIBILITY.txt", DST / "REPRODUCIBILITY.txt")
    copy_file(MS / "STATUS_ITENS_TECNICOS.md", DST / "STATUS_ITENS_TECNICOS.md")
    copy_file(MS / "Access-2026-38745_REVISION_TABLES.tex", DST / "Access-2026-38745_REVISION_TABLES.tex")
    copy_file(SCRIPTS / "PASSO_A_PASSO_ACCESS_R43D_PINBARE.txt", DST / "PROTOCOLO.txt")

    pin_src = ORACLE / "guest" / "pin_bare_guest_n3"
    tree_src = ORACLE / "access_r43d"
    shutil.copytree(pin_src, DST / "1_pin_sem_pintool")
    shutil.copytree(tree_src, DST / "2_arvores_r43d")

    csv_dir = DST / "csv"
    for src in (
        ORACLE / "access_r43d_summary.csv",
        ORACLE / "access_r43d_cell_medians.csv",
        ORACLE / "pin_bare_guest_n3_summary.csv",
        ORACLE / "fidelity_pairs_2230.csv",
        ROOT / "experiment" / "results" / "campaign" / "corpus_aligned_10k" / "nat_empty_tmw0_table.csv",
        ORACLE / "r43d_ingest_manifest.json",
    ):
        if src.exists():
            copy_file(src, csv_dir / src.name)

    ident = json.loads((ORACLE / "r43d_ingest_manifest.json").read_text(encoding="utf-8"))
    ident["pack"] = PACK_NAME
    ident["for"] = "response to the three pendencies — NOT IEEE — not the full article"
    ident["n_9000_rerun"] = False
    ident["limitations_not_run"] = [
        "full temporal coherence",
        "interface matrix / new DLL vs 9000",
        "paired behavioural traces",
        "malware check-branch-recovered-behavior case",
        "Arancino/COBAI/Peekaboo bake-off",
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
