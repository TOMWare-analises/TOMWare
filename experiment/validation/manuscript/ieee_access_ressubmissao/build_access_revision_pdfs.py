# -*- coding: utf-8 -*-
"""Build English letter + insert PDFs (clean and highlighted). Not the IEEE article compile."""
from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, KeepTogether

HERE = Path(__file__).resolve().parent
OUT = HERE.parent
FONTS = Path(r"C:\Windows\Fonts")
if (FONTS / "arial.ttf").exists():
    pdfmetrics.registerFont(TTFont("Body", str(FONTS / "arial.ttf")))
    pdfmetrics.registerFont(TTFont("Body-Bold", str(FONTS / "arialbd.ttf")))
    BODY, BOLD = "Body", "Body-Bold"
else:
    BODY, BOLD = "Times-Roman", "Times-Bold"

NAVY = colors.HexColor("#1a365d")
YELLOW = colors.HexColor("#fff3bf")


def styles(hl: bool):
    s = getSampleStyleSheet()
    back = YELLOW if hl else colors.white
    s.add(ParagraphStyle(name="T", fontName=BOLD, fontSize=12, leading=15, alignment=TA_CENTER, spaceAfter=6, textColor=NAVY))
    s.add(ParagraphStyle(name="Sub", fontName=BODY, fontSize=8, leading=10, alignment=TA_CENTER, spaceAfter=10))
    s.add(ParagraphStyle(name="H", fontName=BOLD, fontSize=10.5, leading=13, spaceBefore=9, spaceAfter=3, textColor=NAVY))
    s.add(ParagraphStyle(name="H2", fontName=BOLD, fontSize=9.2, leading=12, spaceBefore=6, spaceAfter=2, textColor=colors.HexColor("#2c5282")))
    s.add(
        ParagraphStyle(
            name="B",
            fontName=BODY,
            fontSize=8.6,
            leading=11.2,
            alignment=TA_JUSTIFY,
            spaceAfter=3,
            backColor=back,
        )
    )
    s.add(ParagraphStyle(name="L", fontName=BODY, fontSize=8.4, leading=11.0, alignment=TA_LEFT, leftIndent=10, spaceAfter=1, backColor=back))
    return s


def esc(t: str) -> str:
    return (
        t.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("`", "")
    )


def flow_from_md(path: Path, st, title: str, sub: str):
    story = [Paragraph(esc(title), st["T"]), Paragraph(esc(sub), st["Sub"])]
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not line or line.startswith("---"):
            continue
        if line.startswith("# "):
            continue
        if line.startswith("## "):
            story.append(Paragraph(esc(line[3:]), st["H"]))
            continue
        if line.startswith("### "):
            story.append(Paragraph(esc(line[4:]), st["H2"]))
            continue
        if line.startswith("|") and "---" in line:
            continue
        if line.startswith("|"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            story.append(Paragraph(esc(" — ".join(cells)), st["L"]))
            continue
        if line.startswith("- "):
            story.append(Paragraph("• " + esc(line[2:]), st["L"]))
            continue
        story.append(Paragraph(esc(line), st["B"]))
    return story


def write_pdf(out: Path, story, hl: bool):
    doc = SimpleDocTemplate(
        str(out),
        pagesize=letter,
        leftMargin=0.7 * inch,
        rightMargin=0.7 * inch,
        topMargin=0.6 * inch,
        bottomMargin=0.6 * inch,
        title=out.stem,
    )
    doc.build(story)
    print("WROTE", out, out.stat().st_size)


def main() -> None:
    sub_hl = "HIGHLIGHTED DRAFT — mark these sentences with \\hl in Overleaf, then export a clean PDF."
    sub_clean = "Clean English inserts / letter. Not the IEEE-formatted article. Collaborator compile remains Overleaf."
    for hl, suffix, sub in (
        (False, "", sub_clean),
        (True, "_HL", sub_hl),
    ):
        st = styles(hl)
        write_pdf(
            OUT / f"Access-2026-38745_Manuscript_Inserts{suffix}.pdf",
            flow_from_md(HERE / "INSERCOES_EN.md", st, "Access-2026-38745 — English manuscript inserts", sub),
            hl,
        )
        write_pdf(
            OUT / f"Access-2026-38745_Response_to_Reviewers{suffix if hl else ''}.pdf",
            flow_from_md(HERE / "CARTA_PONTO_A_PONTO_EN.md", st, "Response to Reviewers — Access-2026-38745", sub),
            hl,
        )


if __name__ == "__main__":
    main()
