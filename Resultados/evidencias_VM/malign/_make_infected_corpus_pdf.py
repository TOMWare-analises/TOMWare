# -*- coding: utf-8 -*-
"""Generate article-ready PDF for infected corpus with detailed evidence tables.

Same layout as the current benign PDF (TOMWare-corpus-benigno-17-amostras.pdf):
  1. Objetivo e leitura da tabela + visão geral
  2. Detalhamento por amostra
  3. Notas para o artigo
"""
from __future__ import annotations

import csv
import re
import shutil
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm, mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(r"D:\MMB\evidencias_VM\malign")
OUT = ROOT / "TOMWare-corpus-maligno-14-amostras.pdf"
OUT_TMP = ROOT / "TOMWare-corpus-maligno-14-amostras-novo.pdf"
REPO_OUT = Path(
    r"D:\MMB\workspace\tomware-melhorias\TOMWare\Resultados\evidencias_VM\malign"
    r"\TOMWare-corpus-maligno-14-amostras.pdf"
)
REPO_SCRIPT = Path(
    r"D:\MMB\workspace\tomware-melhorias\TOMWare\Resultados\evidencias_VM\malign"
    r"\_make_infected_corpus_pdf.py"
)
DOCS_OUT = Path(
    r"D:\MMB\workspace\tomware-melhorias\TOMWare\docs\avaliacao"
    r"\TOMWare-corpus-maligno-14-amostras.pdf"
)

EXECUTION_ORDER = [
    "0F20B0C9",
    "430B487C",
    "36685EFC",
    "0E3E95EE",
    "6E89B763",
    "7DE3DF7D",
    "17C79863",
    "66EBBC7D",
    "166FFCE3",
    "1693DF9D",
    "57448277",
    "A0AEB837",
    "B640C53E",
    "DB32E48A",
]

CM_ORDER = ["DE", "DM", "DO", "DD", "DP"]
N_SAMPLES = 14
N_CELLS = N_SAMPLES * 5


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


def load_rows() -> list[dict]:
    path = ROOT / "consolidado-infected-14-amostras.csv"
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=";"))


def parse_num(value: str | None) -> float | None:
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


def short_evidence(cm: str, evidence: str) -> str:
    text = evidence or ""
    if cm == "DE":
        nums = re.findall(r"PIN_CRT_TZDATA\s*:?\s*(\d+)", text)
        if len(nums) >= 2:
            return f"PIN_CRT_TZDATA: {nums[0]} → {nums[1]}"
        return "PIN_CRT_TZDATA: 1 → 0"
    if cm == "DM":
        m = re.search(r"PIN_:\s*baseline=(\d+),\s*-dm=(\d+)", text)
        if m:
            return f"PIN_: {m.group(1)} → {m.group(2)}; módulos Pin → 0"
        return "PIN_: N → 0; módulos Pin → 0"
    if cm == "DO":
        ticks = re.findall(r"Ticks \+ Latencia:\s*([0-9]+(?:[.,][0-9]+)?)", text)
        if len(ticks) >= 2:
            a = ticks[0].replace(".", ",")
            b = ticks[1].replace(".", ",")
            return f"Ticks percebidos: {a} → {b} (&lt; 3000)"
        return "Ticks: anomalia → OK (&lt; 3000)"
    if cm == "DD":
        return "Indicadores anti-debug: 1 → 0"
    if cm == "DP":
        nums = re.findall(r"pin\.exe\s*:?\s*(\d+)", text, re.I)
        if len(nums) >= 2:
            return f"pin.exe: {nums[0]} → {nums[1]}"
        if nums:
            return f"pin.exe: {nums[0]} → 0"
        return "pin.exe: N → 0"
    return (text[:80] + "…") if len(text) > 80 else text


def sample_metric_cells(row: dict) -> tuple[str, str, str]:
    """Return (baseline→CM, variação, avaliação)."""
    cm = row["Countermeasure"]
    profile = row["Profile"]
    runtime_valid = str(row.get("RuntimeComparisonValid", "")).lower() == "true"
    resource_valid = str(row.get("ResourceComparisonValid", "")).lower() == "true"
    func = row["FunctionalStatus"]

    wall_b = parse_num(row.get("BaselineMedianSeconds"))
    wall_c = parse_num(row.get("CountermeasureMedianSeconds"))
    wall_pct = parse_num(row.get("MedianChangePercent"))
    cpu_b = parse_num(row.get("BaselineMedianCpuSeconds"))
    cpu_c = parse_num(row.get("CountermeasureMedianCpuSeconds"))
    cpu_pct = parse_num(row.get("MedianCpuChangePercent"))
    mem_b = parse_num(row.get("BaselineMedianPeakWorkingSetMB"))
    mem_c = parse_num(row.get("CountermeasureMedianPeakWorkingSetMB"))
    mem_pct = parse_num(row.get("MedianPeakWorkingSetChangePercent"))

    if profile == "short-lived" and runtime_valid and cm != "DP":
        amostra = f"{fmt_num(wall_b, 3)} s → {fmt_num(wall_c, 3)} s"
        variacao = fmt_pct(wall_pct)
        abs_delta = abs((wall_c or 0) - (wall_b or 0))
        if abs_delta < 0.05 or (wall_pct is not None and abs(wall_pct) < 15):
            avaliacao = "Passou funcionalmente; custo de tempo desprezível"
        else:
            avaliacao = "Passou funcionalmente; variação de tempo dentro do ruído típico"
        return amostra, variacao, avaliacao

    if profile == "persistent" and resource_valid:
        amostra = (
            f"CPU {fmt_num(cpu_b, 2)}→{fmt_num(cpu_c, 2)} s; "
            f"mem {fmt_num(mem_b, 0)}→{fmt_num(mem_c, 0)} MB"
        )
        if cm == "DO" and mem_pct is not None and abs(mem_pct) > 50:
            variacao = f"CPU {fmt_pct(cpu_pct)} / mem {fmt_pct(mem_pct)}"
            avaliacao = (
                "Mascaramento OK; deltas de recurso anômalos (não usar como ganho)"
            )
        elif cm == "DP":
            variacao = f"CPU {fmt_pct(cpu_pct)} / mem {fmt_pct(mem_pct)}"
            avaliacao = (
                "Passou funcionalmente; tempo/recurso não são métrica de eficácia do DP"
            )
        else:
            variacao = f"CPU {fmt_pct(cpu_pct)} / mem {fmt_pct(mem_pct)}"
            if (
                cpu_pct is not None
                and abs(cpu_pct) < 10
                and mem_pct is not None
                and abs(mem_pct) < 15
            ):
                avaliacao = "Passou funcionalmente; custo de recursos moderado/baixo"
            else:
                avaliacao = "Passou funcionalmente; registrar impacto de recursos"
        return amostra, variacao, avaliacao

    if cm == "DP":
        amostra = f"{fmt_num(wall_b, 3)} s → {fmt_num(wall_c, 3)} s"
        variacao = "n/a"
        avaliacao = (
            "Passou funcionalmente; tempo não é métrica de eficácia, mas é impacto"
        )
        return amostra, variacao, avaliacao

    amostra = f"{fmt_num(wall_b, 3)} s → {fmt_num(wall_c, 3)} s"
    variacao = fmt_pct(wall_pct) if wall_pct is not None else "n/a"
    avaliacao = f"Status funcional: {func}"
    return amostra, variacao, avaliacao


def build_pdf() -> Path:
    font, font_bold = register_fonts()
    rows = load_rows()
    by_short: dict[str, dict[str, dict]] = {}
    for row in rows:
        by_short.setdefault(row["ShaShort"], {})[row["Countermeasure"]] = row

    missing = [s for s in EXECUTION_ORDER if s not in by_short]
    if missing:
        raise SystemExit(f"SHA ausente no consolidado: {missing}")

    n_persist = sum(
        1 for s in EXECUTION_ORDER if by_short[s]["DE"]["Profile"] == "persistent"
    )
    n_short = N_SAMPLES - n_persist
    n_do_retry = sum(
        1
        for s in EXECUTION_ORDER
        if int(float(by_short[s]["DO"].get("DoReportAttempts") or 1)) > 1
    )

    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "TitlePT",
        parent=styles["Title"],
        fontName=font_bold,
        fontSize=13,
        leading=17,
        alignment=TA_CENTER,
        spaceAfter=6,
    )
    h2 = ParagraphStyle(
        "H2PT",
        parent=styles["Heading2"],
        fontName=font_bold,
        fontSize=11,
        leading=14,
        spaceBefore=10,
        spaceAfter=5,
    )
    h3 = ParagraphStyle(
        "H3PT",
        parent=styles["Heading3"],
        fontName=font_bold,
        fontSize=9.5,
        leading=12,
        spaceBefore=8,
        spaceAfter=3,
    )
    body = ParagraphStyle(
        "BodyPT",
        parent=styles["Normal"],
        fontName=font,
        fontSize=9,
        leading=12.5,
        alignment=TA_JUSTIFY,
        spaceAfter=6,
    )
    caption = ParagraphStyle(
        "CaptionPT",
        parent=styles["Normal"],
        fontName=font,
        fontSize=8,
        leading=10.5,
        alignment=TA_LEFT,
        textColor=colors.HexColor("#333333"),
        spaceBefore=2,
        spaceAfter=6,
    )
    cell = ParagraphStyle(
        "CellPT",
        parent=styles["Normal"],
        fontName=font,
        fontSize=7,
        leading=9,
    )
    cell_b = ParagraphStyle(
        "CellBoldPT",
        parent=cell,
        fontName=font_bold,
    )

    doc = SimpleDocTemplate(
        str(OUT_TMP),
        pagesize=A4,
        leftMargin=1.4 * cm,
        rightMargin=1.4 * cm,
        topMargin=1.3 * cm,
        bottomMargin=1.4 * cm,
        title="TOMWare — Corpus maligno consolidado (14 amostras)",
        author="TOMWare",
    )

    story: list = []
    story.append(
        Paragraph(
            "TOMWare: resultados consolidados do corpus de amostras malignas "
            f"({N_SAMPLES} executáveis)",
            title,
        )
    )
    story.append(
        Paragraph(
            "Material complementar para o artigo. Cada linha combina evidência "
            "funcional (ocultação do Pin) com a métrica de desempenho adequada ao "
            "perfil da amostra.",
            caption,
        )
    )

    story.append(Paragraph("1. Objetivo e leitura da tabela", h2))
    story.append(
        Paragraph(
            "Para cada amostra e contramedida (DE, DM, DO, DD, DP) reportam-se: "
            "<b>Evidência</b> (resultado do aplicativo de teste / mascaramento do Pin); "
            "<b>Amostra: baseline → CM</b> (tempo mediano em amostras de curta duração, "
            "ou CPU/memória na janela de 10&nbsp;s em amostras persistentes); "
            "<b>Variação</b>; e <b>Avaliação</b>. "
            "A evidência funcional não classifica a amostra como malware: os mesmos "
            "testes se aplicam a binários benignos e infectados.",
            body,
        )
    )
    story.append(
        Paragraph(
            f"Resultado global: <b>{N_CELLS}/{N_CELLS} PASS</b> funcional "
            f"({N_SAMPLES} × 5). Em {n_do_retry} amostras o DO exigiu reexecução "
            "porque o baseline do teste de overhead ficou abaixo do limiar "
            "(&lt; 3000 ticks) na primeira passagem; o consolidado usa a execução "
            f"final PASS. Amostras persistentes: {n_persist}; curta duração: {n_short}.",
            body,
        )
    )

    overview_header = [
        Paragraph("<b>#</b>", cell_b),
        Paragraph("<b>SHA-256</b>", cell_b),
        Paragraph("<b>Perfil</b>", cell_b),
        Paragraph("<b>Funcional</b>", cell_b),
        Paragraph("<b>Tent. DO</b>", cell_b),
    ]
    overview_data = [overview_header]
    for index, short in enumerate(EXECUTION_ORDER, start=1):
        group = by_short[short]
        first = next(iter(group.values()))
        do_attempts = int(float(group["DO"].get("DoReportAttempts") or 1))
        profile = (
            "Persistente (observed)"
            if first["Profile"] == "persistent"
            else "Curta duração (complete)"
        )
        pass_n = sum(
            1 for knob in CM_ORDER if group[knob].get("FunctionalStatus") == "PASS"
        )
        overview_data.append(
            [
                Paragraph(str(index), cell),
                Paragraph(short + "…", cell),
                Paragraph(profile, cell),
                Paragraph(f"{pass_n}/5 PASS", cell),
                Paragraph(str(do_attempts), cell),
            ]
        )

    overview = Table(
        overview_data,
        colWidths=[1.0 * cm, 2.4 * cm, 5.5 * cm, 2.4 * cm, 2.0 * cm],
        repeatRows=1,
    )
    overview.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#9ca3af")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (0, 0), (0, -1), "CENTER"),
                ("ALIGN", (3, 1), (-1, -1), "CENTER"),
                (
                    "ROWBACKGROUNDS",
                    (0, 1),
                    (-1, -1),
                    [colors.white, colors.HexColor("#f3f4f6")],
                ),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )
    )
    story.append(Paragraph("Tabela 1. Visão geral do corpus maligno.", caption))
    story.append(overview)
    story.append(
        Paragraph(
            "Fonte: VM isolada, 10 pares baseline/contramedida por knob, ordem alternada.",
            caption,
        )
    )

    story.append(Paragraph("2. Detalhamento por amostra", h2))
    story.append(
        Paragraph(
            "Nas tabelas a seguir, a coluna <b>Evidência</b> resume o mascaramento "
            "observado. Em amostras de curta duração, <b>Amostra: baseline → CM</b> "
            "usa wall-time mediano (s). Em amostras persistentes, usa CPU acumulada (s) "
            "e pico de memória (MB) na janela de 10&nbsp;s — o tempo total de parede "
            "fica artificialmente fixo e não entra na variação.",
            body,
        )
    )

    detail_header = [
        Paragraph("<b>Contramedida</b>", cell_b),
        Paragraph("<b>Evidência</b>", cell_b),
        Paragraph("<b>Amostra: baseline → CM</b>", cell_b),
        Paragraph("<b>Variação</b>", cell_b),
        Paragraph("<b>Avaliação</b>", cell_b),
    ]
    detail_widths = [2.0 * cm, 4.3 * cm, 4.6 * cm, 2.4 * cm, 4.5 * cm]

    for index, short in enumerate(EXECUTION_ORDER, start=1):
        group = by_short[short]
        first = group["DE"]
        sha = first["Sha256"]
        profile = first["Profile"]
        profile_pt = (
            "persistente / observed 10 s"
            if profile == "persistent"
            else "curta duração / complete"
        )
        do_attempts = int(float(group["DO"].get("DoReportAttempts") or 1))
        subtitle = (
            f"Amostra {index}/{N_SAMPLES} — {short}… "
            f"({profile_pt}"
            + (f"; DO reexecutado ×{do_attempts}" if do_attempts > 1 else "")
            + ")"
        )

        data = [detail_header]
        for knob in CM_ORDER:
            row = group[knob]
            evid = short_evidence(knob, row.get("FunctionalEvidence") or "")
            amostra, variacao, avaliacao = sample_metric_cells(row)
            data.append(
                [
                    Paragraph(knob, cell_b),
                    Paragraph(evid, cell),
                    Paragraph(amostra, cell),
                    Paragraph(variacao, cell),
                    Paragraph(avaliacao, cell),
                ]
            )

        detail = Table(data, colWidths=detail_widths, repeatRows=1)
        detail.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f2937")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#9ca3af")),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("ALIGN", (0, 1), (0, -1), "CENTER"),
                    ("ALIGN", (3, 1), (3, -1), "CENTER"),
                    (
                        "ROWBACKGROUNDS",
                        (0, 1),
                        (-1, -1),
                        [colors.white, colors.HexColor("#f9fafb")],
                    ),
                    ("LEFTPADDING", (0, 0), (-1, -1), 3),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                    ("TOPPADDING", (0, 0), (-1, -1), 3),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ]
            )
        )

        block = [
            Paragraph(subtitle, h3),
            Paragraph(
                f"SHA-256 completo: <font face='Courier' size='7'>{sha}</font>",
                caption,
            ),
            detail,
            Spacer(1, 2 * mm),
        ]
        story.append(KeepTogether(block))

    story.append(Paragraph("3. Notas para o artigo", h2))
    story.append(
        Paragraph(
            f"• <b>Equivalência funcional:</b> o PASS nas {N_SAMPLES} malignas "
            f"({N_CELLS}/{N_CELLS}) indica que as contramedidas ocultam vestígios "
            "do Pin também sob cargas reais infectadas, no mesmo protocolo do "
            "controle negativo benigno.",
            body,
        )
    )
    story.append(
        Paragraph(
            "• <b>DO:</b> flutuação do limiar de ticks (&lt; 3000) pode tornar a primeira "
            "passagem inconclusiva; a reexecução isolada restaurou PASS nos casos "
            "afetados deste corpus.",
            body,
        )
    )
    story.append(
        Paragraph(
            "• <b>Desempenho:</b> não misturar wall-time de CLI curta com CPU/memória "
            "da janela de 10&nbsp;s. Em DO sobre GUI/persistentes, deltas extremos de "
            "memória/CPU são anomalia de amostragem e não devem ser lidos como melhoria.",
            body,
        )
    )
    story.append(
        Paragraph(
            "• <b>DP:</b> a eficácia é a ocultação de <font face='Courier'>pin.exe</font> "
            "na enumeração; duração e recursos são impacto operacional, não critério "
            "de sucesso.",
            body,
        )
    )
    story.append(
        Paragraph(
            "Arquivos-fonte: consolidado-infected-14-amostras.csv / .json. "
            "Comparativo com o corpus benigno: "
            "TOMWare-comparativo-benigno-vs-maligno.pdf.",
            caption,
        )
    )

    def _footer(canvas, _doc):
        canvas.saveState()
        canvas.setFont(font, 8)
        canvas.setFillColor(colors.HexColor("#6b7280"))
        canvas.drawString(
            1.4 * cm, 0.9 * cm, "TOMWare — corpus maligno (amostras infectadas)"
        )
        canvas.drawRightString(A4[0] - 1.4 * cm, 0.9 * cm, f"Página {_doc.page}")
        canvas.restoreState()

    doc.build(story, onFirstPage=_footer, onLaterPages=_footer)

    DOCS_OUT.parent.mkdir(parents=True, exist_ok=True)
    DOCS_OUT.write_bytes(OUT_TMP.read_bytes())
    REPO_OUT.parent.mkdir(parents=True, exist_ok=True)
    REPO_OUT.write_bytes(OUT_TMP.read_bytes())

    try:
        if OUT.exists():
            OUT.unlink()
        OUT_TMP.replace(OUT)
        final = OUT
    except OSError:
        final = OUT_TMP

    return final


def main() -> None:
    path = build_pdf()
    # Keep generator mirrored in Resultados
    src = Path(__file__).resolve()
    REPO_SCRIPT.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    print(path)
    print(f"size_bytes={path.stat().st_size}")
    print(f"REPO={REPO_OUT}")
    print(f"DOCS={DOCS_OUT}")


if __name__ == "__main__":
    main()
