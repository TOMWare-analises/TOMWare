# -*- coding: utf-8 -*-
"""Merge phase documents from the workspace root into a single file."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path

from docx import Document
from docx.enum.text import WD_BREAK
from docx.shared import Pt

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = Path(__file__).resolve().parents[1] / "docs"

SECTIONS = [
    ("Initial diagnosis", WORKSPACE_ROOT / "Diagnóstico.docx"),
    ("Phase 1 — Stabilization and operational baseline", WORKSPACE_ROOT / "fase1_ok.docx"),
    ("Phase 2 — AntiDebugMask (-dd)", WORKSPACE_ROOT / "fase2_ok.docx"),
    ("Phase 3 — ProcessEnumMask (-dp) and signatures (-sf)", WORKSPACE_ROOT / "fase3_ok.docx"),
    ("Phase 4 — Benchmark and DBI-Log corpus", WORKSPACE_ROOT / "fase4_ok.docx"),
    ("Phase 5 — Local compilation and tests", WORKSPACE_ROOT / "fase5_compilar_testar.docx"),
    ("Phase 6 — Tests on the VMware VM", WORKSPACE_ROOT / "fase6_rodar_testes_na_VMWare.docx"),
]


def extract_paragraphs(path: Path) -> list[str]:
    doc = Document(str(path))
    lines: list[str] = []
    for para in doc.paragraphs:
        text = para.text.strip()
        if text:
            lines.append(text)
    return lines


def extract_tables(path: Path) -> list[list[list[str]]]:
    doc = Document(str(path))
    tables: list[list[list[str]]] = []
    for table in doc.tables:
        rows: list[list[str]] = []
        for row in table.rows:
            rows.append([cell.text.strip() for cell in row.cells])
        if rows:
            tables.append(rows)
    return tables


def slugify(title: str) -> str:
    t = title.lower()
    t = re.sub(r"[^\w\s-]", "", t, flags=re.UNICODE)
    t = re.sub(r"\s+", "-", t.strip())
    return t[:60]


def add_heading(doc: Document, text: str, level: int = 1) -> None:
    doc.add_heading(text, level=level)


def add_paragraphs(doc: Document, lines: list[str]) -> None:
    for line in lines:
        doc.add_paragraph(line)


def add_table_markdown(lines: list[str], rows: list[list[str]]) -> None:
    if not rows:
        return
    header = rows[0]
    lines.append("")
    lines.append("| " + " | ".join(header) + " |")
    lines.append("| " + " | ".join(["---"] * len(header)) + " |")
    for row in rows[1:]:
        lines.append("| " + " | ".join(row) + " |")
    lines.append("")


def build_markdown(sections: list[tuple[str, list[str], list[list[list[str]]]]]) -> str:
    now = datetime.now().strftime("%Y-%m-%d")
    md: list[str] = [
        "# TOMWare — Evolution of improvements by phase",
        "",
        f"Document consolidated on {now} from the diagnosis records and phases 1–6.",
        "",
        "Repository: [TOMWare-DBI/TOMWare](https://github.com/TOMWare-DBI/TOMWare)",
        "",
        "---",
        "",
    ]

    for idx, (title, paras, tables) in enumerate(sections, start=1):
        md.append(f"## {idx}. {title}")
        md.append("")
        for p in paras:
            md.append(p)
            md.append("")
        for table in tables:
            add_table_markdown(md, table)
        md.append("---")
        md.append("")

    md.append("## Evolution summary")
    md.append("")
    md.append("| Phase | Main focus | Deliverable |")
    md.append("|------|----------------|------------|")
    md.append("| Diagnosis | Gaps vs DBI-Log and anti-debug | Improvement plan |")
    md.append("| 1 | Stability, logging, `-da`/`-go`, scripts | Release operational baseline |")
    md.append("| 2 | AntiDebugMask (`-dd`) | PoC TestAntiDebug |")
    md.append("| 3 | ProcessEnumMask (`-dp`), signatures (`-sf`) | PoC TestProcessEnum |")
    md.append("| 4 | Benchmark, corpus manifesto, metrics | Phase 4 scripts |")
    md.append("| 5 | Local compilation and validation | Release x64 build |")
    md.append("| 6 | VM execution, real malware, evidence | Evaluation on real samples |")
    md.append("")

    return "\n".join(md)


def build_docx(sections: list[tuple[str, list[str], list[list[list[str]]]]]) -> Document:
    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)

    add_heading(doc, "TOMWare — Evolution of improvements by phase", level=0)
    doc.add_paragraph(
        f"Document consolidated on {datetime.now():%Y-%m-%d} "
        "from the initial diagnosis and the phase 1–6 records."
    )
    doc.add_paragraph("Repository: https://github.com/TOMWare-DBI/TOMWare")

    for idx, (title, paras, tables) in enumerate(sections, start=1):
        doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
        add_heading(doc, f"{idx}. {title}", level=1)
        add_paragraphs(doc, paras)
        for table in tables:
            if not table:
                continue
            t = doc.add_table(rows=len(table), cols=len(table[0]))
            t.style = "Table Grid"
            for r_idx, row in enumerate(table):
                for c_idx, cell in enumerate(row):
                    t.rows[r_idx].cells[c_idx].text = cell
            doc.add_paragraph("")

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    add_heading(doc, "Evolution summary", level=1)
    summary = [
        ("Diagnosis", "Gaps vs DBI-Log and anti-debug", "Improvement plan"),
        ("Phase 1", "Stability, logging, scripts", "Release operational baseline"),
        ("Phase 2", "AntiDebugMask (-dd)", "PoC TestAntiDebug"),
        ("Phase 3", "ProcessEnumMask (-dp), -sf", "PoC TestProcessEnum"),
        ("Phase 4", "Benchmark and corpus", "Phase 4 scripts"),
        ("Phase 5", "Local compilation", "Release x64 build"),
        ("Phase 6", "VM and real malware", "Evaluation on real samples"),
    ]
    st = doc.add_table(rows=1 + len(summary), cols=3)
    st.style = "Table Grid"
    hdr = st.rows[0].cells
    hdr[0].text = "Phase"
    hdr[1].text = "Main focus"
    hdr[2].text = "Deliverable"
    for i, row in enumerate(summary, start=1):
        st.rows[i].cells[0].text = row[0]
        st.rows[i].cells[1].text = row[1]
        st.rows[i].cells[2].text = row[2]

    return doc


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    collected: list[tuple[str, list[str], list[list[list[str]]]]] = []

    for title, path in SECTIONS:
        if not path.exists():
            raise FileNotFoundError(f"File not found: {path}")
        collected.append((title, extract_paragraphs(path), extract_tables(path)))

    md_path = OUT_DIR / "EVOLUCAO-MELHORIAS-POR-FASES.md"
    docx_path = OUT_DIR / "EVOLUCAO-MELHORIAS-POR-FASES.docx"

    md_path.write_text(build_markdown(collected), encoding="utf-8")
    build_docx(collected).save(str(docx_path))

    print(f"OK: {md_path}")
    print(f"OK: {docx_path}")


if __name__ == "__main__":
    main()
