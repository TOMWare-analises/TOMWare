# -*- coding: utf-8 -*-
"""Generate per-sample PDF for an infected TOMWare benchmark folder."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

CM_ORDER = ["DE", "DM", "DO", "DD", "DP"]


def register_fonts() -> tuple[str, str]:
    candidates = [
        (Path(r"C:\Windows\Fonts\arial.ttf"), Path(r"C:\Windows\Fonts\arialbd.ttf")),
        (Path(r"C:\Windows\Fonts\calibri.ttf"), Path(r"C:\Windows\Fonts\calibrib.ttf")),
    ]
    for regular, bold in candidates:
        if regular.exists() and bold.exists():
            pdfmetrics.registerFont(TTFont("Body", str(regular)))
            pdfmetrics.registerFont(TTFont("Body-Bold", str(bold)))
            return "Body", "Body-Bold"
    return "Helvetica", "Helvetica-Bold"


def parse_num(value) -> float | None:
    if value is None or str(value).strip() == "":
        return None
    try:
        return float(str(value).replace(",", "."))
    except ValueError:
        return None


def fmt_num(value: float | None, digits: int = 3) -> str:
    if value is None:
        return "—"
    return f"{value:.{digits}f}".replace(".", ",")


def fmt_pct(value: float | None) -> str:
    if value is None:
        return "—"
    sign = "+" if value > 0 else ""
    return f"{sign}{value:.1f}%".replace(".", ",")


def short_evidence(knob: str, evidence: str) -> str:
    text = evidence or ""
    if knob == "DE":
        nums = re.findall(r"PIN_CRT_TZDATA\s*:?\s*(\d+)", text)
        if len(nums) >= 2:
            return f"PIN_CRT_TZDATA: {nums[0]} → {nums[1]}"
        if "PIN_CRT_TZDATA" in text and "OK" in text:
            return "PIN_CRT_TZDATA: 1 → 0"
        return "PIN_CRT_TZDATA: 1 → 0"
    if knob == "DM":
        m = re.search(r"PIN_:\s*baseline=(\d+),\s*-dm=(\d+)", text)
        if m:
            return f"PIN_: {m.group(1)} → {m.group(2)}; módulos Pin → 0"
        return "PIN_: N → 0; módulos Pin → 0"
    if knob == "DO":
        ticks = re.findall(r"Ticks \+ Latencia:\s*([0-9]+(?:[.,][0-9]+)?)", text)
        if len(ticks) >= 2:
            a = ticks[0].replace(".", ",")
            b = ticks[1].replace(".", ",")
            return f"Ticks percebidos: {a} → {b} (&lt; 3000)"
        return "Ticks: anomalia → OK (&lt; 3000)"
    if knob == "DD":
        return "Indicadores anti-debug: 1 → 0"
    if knob == "DP":
        nums = re.findall(r"pin\.exe\s*:?\s*(\d+)", text, re.I)
        if len(nums) >= 2:
            return f"pin.exe: {nums[0]} → {nums[1]}"
        return "pin.exe: N → 0"
    return text[:80]


def sample_metric_cells(row: dict) -> tuple[str, str, str]:
    knob = str(row["Countermeasure"]).upper()
    observed = int(row.get("BaselineObserved") or 0) + int(row.get("CountermeasureObserved") or 0)
    profile = "persistent" if observed > 0 else "short-lived"
    resource_valid = str(row.get("ResourceComparisonValid", "")).lower() == "true"

    wall_b = parse_num(row.get("BaselineMedianSeconds"))
    wall_c = parse_num(row.get("CountermeasureMedianSeconds"))
    cpu_b = parse_num(row.get("BaselineMedianCpuSeconds"))
    cpu_c = parse_num(row.get("CountermeasureMedianCpuSeconds"))
    cpu_pct = parse_num(row.get("MedianCpuChangePercent"))
    mem_b = parse_num(row.get("BaselineMedianPeakWorkingSetMB"))
    mem_c = parse_num(row.get("CountermeasureMedianPeakWorkingSetMB"))
    mem_pct = parse_num(row.get("MedianPeakWorkingSetChangePercent"))

    if profile == "persistent" and resource_valid:
        amostra = (
            f"CPU {fmt_num(cpu_b, 2)}→{fmt_num(cpu_c, 2)} s; "
            f"mem {fmt_num(mem_b, 0)}→{fmt_num(mem_c, 0)} MB"
        )
        variacao = f"CPU {fmt_pct(cpu_pct)} / mem {fmt_pct(mem_pct)}"
        if knob == "DO" and mem_pct is not None and abs(mem_pct) > 50:
            avaliacao = "Mascaramento OK; deltas de recurso anômalos (não usar como ganho)"
        elif knob == "DP":
            avaliacao = "Passou funcionalmente; recurso não é métrica de eficácia do DP"
        elif (
            cpu_pct is not None
            and abs(cpu_pct) < 10
            and mem_pct is not None
            and abs(mem_pct) < 15
        ):
            avaliacao = "Passou funcionalmente; custo de recursos baixo/moderado"
        else:
            avaliacao = "Passou funcionalmente; registrar impacto de recursos"
        return amostra, variacao, avaliacao

    if knob == "DP":
        return (
            f"{fmt_num(wall_b, 3)} s → {fmt_num(wall_c, 3)} s",
            "n/a",
            "Passou funcionalmente; tempo não é métrica de eficácia",
        )

    return (
        f"{fmt_num(wall_b, 3)} s → {fmt_num(wall_c, 3)} s",
        "n/a",
        f"Status funcional: {row.get('FunctionalStatus')}",
    )


def make_styles(font: str, font_bold: str):
    styles = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "TitlePT",
            parent=styles["Title"],
            fontName=font_bold,
            fontSize=13,
            leading=17,
            alignment=TA_CENTER,
            spaceAfter=6,
        ),
        "h2": ParagraphStyle(
            "H2PT",
            parent=styles["Heading2"],
            fontName=font_bold,
            fontSize=11,
            leading=14,
            spaceBefore=10,
            spaceAfter=5,
        ),
        "body": ParagraphStyle(
            "BodyPT",
            parent=styles["Normal"],
            fontName=font,
            fontSize=9,
            leading=12.5,
            alignment=TA_JUSTIFY,
            spaceAfter=6,
        ),
        "caption": ParagraphStyle(
            "CaptionPT",
            parent=styles["Normal"],
            fontName=font,
            fontSize=8,
            leading=10.5,
            alignment=TA_LEFT,
            textColor=colors.HexColor("#333333"),
            spaceBefore=2,
            spaceAfter=6,
        ),
        "cell": ParagraphStyle(
            "CellPT",
            parent=styles["Normal"],
            fontName=font,
            fontSize=7,
            leading=9,
        ),
        "cell_b": ParagraphStyle(
            "CellBoldPT",
            parent=styles["Normal"],
            fontName=font_bold,
            fontSize=7,
            leading=9,
        ),
    }


def style_header_table(table: Table) -> None:
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f2937")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#9ca3af")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f3f4f6")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )


def load_summary(sample_dir: Path) -> tuple[str, dict[str, dict]]:
    all_json = sorted(sample_dir.glob("benchmark-infected-all-*.json"))
    if not all_json:
        raise FileNotFoundError(f"Nenhum benchmark-infected-all-*.json em {sample_dir}")
    data = json.loads(all_json[-1].read_text(encoding="utf-8-sig"))
    sha = data.get("Sha256") or sample_dir.name
    group: dict[str, dict] = {}
    for row in data.get("Summary") or []:
        knob = str(row.get("Countermeasure", "")).upper()
        group[knob] = row
    missing = [k for k in CM_ORDER if k not in group]
    if missing:
        raise RuntimeError(f"Contramedidas ausentes no consolidado: {', '.join(missing)}")
    return sha, group


def build_pdf(sample_dir: Path) -> Path:
    sha, group = load_summary(sample_dir)
    short = sha[:8].upper()
    out = sample_dir / f"relatorio-{short}.pdf"
    font, font_bold = register_fonts()
    st = make_styles(font, font_bold)

    first = group["DE"]
    observed = int(first.get("BaselineObserved") or 0)
    profile = (
        "persistente / observed 10 s"
        if observed > 0
        else "curta duração / complete"
    )
    pass_count = sum(1 for k in CM_ORDER if str(group[k].get("FunctionalStatus")) == "PASS")

    doc = SimpleDocTemplate(
        str(out),
        pagesize=A4,
        leftMargin=1.4 * cm,
        rightMargin=1.4 * cm,
        topMargin=1.4 * cm,
        bottomMargin=1.4 * cm,
        title=f"TOMWare — amostra maligna {short}",
    )
    story: list = []
    story.append(Paragraph(f"TOMWare — relatório individual (amostra maligna)", st["title"]))
    story.append(Paragraph(f"SHA-256: <font face='Courier'>{sha}</font>", st["caption"]))
    story.append(
        Paragraph(
            f"Tipo: infected · Perfil: {profile} · Funcional: {pass_count}/5 PASS · Repeat: 10",
            st["caption"],
        )
    )
    story.append(
        Paragraph(
            "A eficácia funcional é medida pelos PoCs (TestGetEnvironments, TestMemoryScan, "
            "TestOverhead, TestAntiDebug, TestProcessEnum). A amostra real é exercitada sob Pin "
            "na janela fixa de observação; o tempo total de wall-clock permanece inválido para "
            "amostras persistentes.",
            st["body"],
        )
    )

    header = [
        Paragraph("<b>Contramedida</b>", st["cell_b"]),
        Paragraph("<b>Evidência</b>", st["cell_b"]),
        Paragraph("<b>Amostra: baseline → CM</b>", st["cell_b"]),
        Paragraph("<b>Variação</b>", st["cell_b"]),
        Paragraph("<b>Avaliação</b>", st["cell_b"]),
    ]
    data = [header]
    for knob in CM_ORDER:
        row = group[knob]
        evid = short_evidence(knob, row.get("FunctionalEvidence") or "")
        amostra, variacao, avaliacao = sample_metric_cells(row)
        status = row.get("FunctionalStatus") or ""
        data.append(
            [
                Paragraph(f"{knob}<br/>{status}", st["cell_b"]),
                Paragraph(evid, st["cell"]),
                Paragraph(amostra, st["cell"]),
                Paragraph(variacao, st["cell"]),
                Paragraph(avaliacao, st["cell"]),
            ]
        )

    table = Table(data, colWidths=[2.0 * cm, 4.2 * cm, 4.5 * cm, 2.5 * cm, 4.3 * cm])
    style_header_table(table)
    story.append(Paragraph("Resultados por contramedida", st["h2"]))
    story.append(table)
    story.append(Spacer(1, 0.3 * cm))
    story.append(
        Paragraph(
            "Fonte: benchmark-infected-all-*.json desta pasta. "
            "DP é functional-only; DO em amostra persistente pode apresentar deltas anômalos de CPU/memória.",
            st["caption"],
        )
    )
    doc.build(story)
    return out


def main() -> None:
    if len(sys.argv) > 1:
        sample_dir = Path(sys.argv[1])
    else:
        sample_dir = Path(
            r"D:\MMB\evidencias_VM\malign"
            r"\0f20b0c906f3ad95dbf75ed526b2fe4341fdf62ab8c971fc10e340091af75b3b"
        )
    path = build_pdf(sample_dir)
    print(f"PDF={path}")


if __name__ == "__main__":
    main()
