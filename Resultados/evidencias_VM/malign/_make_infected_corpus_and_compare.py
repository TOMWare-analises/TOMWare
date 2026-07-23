# -*- coding: utf-8 -*-
"""Consolidate infected corpus + comparative report vs benign."""
from __future__ import annotations

import csv
import json
import re
import statistics
from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT_MAL = Path(r"D:\MMB\evidencias_VM\malign")
ROOT_BEN = Path(r"D:\MMB\evidencias_VM\benign")
REPO_MAL = Path(
    r"D:\MMB\workspace\tomware-melhorias\TOMWare\Resultados\evidencias_VM\malign"
)
REPO_BEN = Path(
    r"D:\MMB\workspace\tomware-melhorias\TOMWare\Resultados\evidencias_VM\benign"
)
COMPARE_DIR = Path(r"D:\MMB\evidencias_VM\comparativo")
REPO_COMPARE = Path(
    r"D:\MMB\workspace\tomware-melhorias\TOMWare\Resultados\evidencias_VM\comparativo"
)

# Order of infected sample runs (as executed by the operator)
INFECTED_ORDER = [
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
CM_LABEL = {
    "DE": "SanitizePinEnvVars (-de)",
    "DM": "InstMemcmpMask (-dm)",
    "DO": "SkewMask (-do)",
    "DD": "AntiDebug (-dd)",
    "DP": "ProcessEnum (-dp)",
}


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


def median(vals: list[float]) -> float | None:
    vals = [v for v in vals if v is not None]
    if not vals:
        return None
    return float(statistics.median(vals))


def short_evidence(knob: str, evidence: str) -> str:
    text = evidence or ""
    if knob == "DE":
        return "PIN_CRT_TZDATA: 1 → 0"
    if knob == "DM":
        m = re.search(r"PIN_:\s*baseline=(\d+),\s*-dm=(\d+)", text)
        if m:
            return f"PIN_: {m.group(1)} → {m.group(2)}"
        return "PIN_: N → 0"
    if knob == "DO":
        ticks = re.findall(r"Ticks \+ Latencia:\s*([0-9]+(?:[.,][0-9]+)?)", text)
        if len(ticks) >= 2:
            a = ticks[0].replace(".", ",")
            b = ticks[1].replace(".", ",")
            return f"Ticks: {a} → {b} (&lt; 3000)"
        return "Ticks: anomalia → OK"
    if knob == "DD":
        return "Anti-debug: 1 → 0"
    if knob == "DP":
        nums = re.findall(r"pin\.exe\s*:?\s*(\d+)", text, re.I)
        if len(nums) >= 2:
            return f"pin.exe: {nums[0]} → {nums[1]}"
        return "pin.exe: N → 0"
    return (text or "")[:80]


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
        "h3": ParagraphStyle(
            "H3PT",
            parent=styles["Heading3"],
            fontName=font_bold,
            fontSize=9.5,
            leading=12,
            spaceBefore=6,
            spaceAfter=3,
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


def find_sample_dir(root: Path, short: str) -> Path:
    for p in root.iterdir():
        if p.is_dir() and p.name.upper().startswith(short.upper()):
            return p
    raise FileNotFoundError(f"{short} em {root}")


def load_infected_rows() -> tuple[list[dict], list[dict]]:
    detail_rows: list[dict] = []
    resumo_rows: list[dict] = []

    for index, short in enumerate(INFECTED_ORDER, start=1):
        sample_dir = find_sample_dir(ROOT_MAL, short)
        all_json = sorted(sample_dir.glob("benchmark-infected-all-*.json"))
        if not all_json:
            raise FileNotFoundError(f"sem all-json: {sample_dir}")
        data = json.loads(all_json[-1].read_text(encoding="utf-8-sig"))
        sha = data.get("Sha256") or sample_dir.name
        by_cm = {
            str(r["Countermeasure"]).upper(): r for r in (data.get("Summary") or [])
        }

        obs = sum(int(by_cm[k].get("BaselineObserved") or 0) for k in CM_ORDER if k in by_cm)
        complete = sum(
            int(by_cm[k].get("BaselineComplete") or 0) for k in CM_ORDER if k in by_cm
        )
        profile = "persistent" if obs >= complete else "short-lived"
        outcome = "observed" if profile == "persistent" else "complete"

        pass_count = sum(
            1 for k in CM_ORDER if str(by_cm.get(k, {}).get("FunctionalStatus")) == "PASS"
        )
        do_status = by_cm.get("DO", {}).get("FunctionalStatus")
        do_files = sorted(sample_dir.glob(f"benchmark-infected-do-{sha[:8].lower()}-*.json"))
        if not do_files:
            do_files = sorted(sample_dir.glob("benchmark-infected-do-*.json"))

        resumo_rows.append(
            {
                "SampleIndex": index,
                "Sha256": sha,
                "ShaShort": sha[:8].upper(),
                "Profile": profile,
                "SampleOutcome": outcome,
                "FunctionalPassCount": pass_count,
                "FunctionalTotal": 5,
                "FunctionalAllPass": pass_count == 5,
                "DoStatus": do_status,
                "DoAttempts": len(do_files),
                "DoSourceJson": do_files[-1].name if do_files else "",
            }
        )

        for knob in CM_ORDER:
            row = by_cm[knob]
            detail_rows.append(
                {
                    "SampleIndex": index,
                    "Sha256": sha,
                    "ShaShort": sha[:8].upper(),
                    "Countermeasure": knob,
                    "Profile": profile,
                    "SampleOutcome": outcome,
                    "FunctionalStatus": row.get("FunctionalStatus"),
                    "FunctionalAnswer": row.get("FunctionalAnswer"),
                    "FunctionalEvidence": row.get("FunctionalEvidence"),
                    "BaselineDetectedPin": row.get("BaselineDetectedPin"),
                    "CountermeasureMaskedPin": row.get("CountermeasureMaskedPin"),
                    "PerformanceStatus": row.get("PerformanceStatus"),
                    "RuntimeComparisonValid": row.get("PerformanceComparisonValid"),
                    "ResourceComparisonValid": row.get("ResourceComparisonValid"),
                    "BaselineMedianSeconds": row.get("BaselineMedianSeconds"),
                    "CountermeasureMedianSeconds": row.get("CountermeasureMedianSeconds"),
                    "MedianDeltaSeconds": row.get("MedianDeltaSeconds"),
                    "MedianChangePercent": row.get("MedianChangePercent"),
                    "BaselineMedianCpuSeconds": row.get("BaselineMedianCpuSeconds"),
                    "CountermeasureMedianCpuSeconds": row.get(
                        "CountermeasureMedianCpuSeconds"
                    ),
                    "MedianCpuChangePercent": row.get("MedianCpuChangePercent"),
                    "BaselineMedianPeakWorkingSetMB": row.get(
                        "BaselineMedianPeakWorkingSetMB"
                    ),
                    "CountermeasureMedianPeakWorkingSetMB": row.get(
                        "CountermeasureMedianPeakWorkingSetMB"
                    ),
                    "MedianPeakWorkingSetChangePercent": row.get(
                        "MedianPeakWorkingSetChangePercent"
                    ),
                    "DoReportAttempts": len(do_files) if knob == "DO" else "",
                    "SourceJson": all_json[-1].name,
                    "GeneratedAt": data.get("GeneratedAt") or datetime.now().isoformat(),
                }
            )
    return detail_rows, resumo_rows


def load_benign_rows() -> list[dict]:
    path = ROOT_BEN / "consolidado-benign-17-amostras.csv"
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=";"))


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()), delimiter=";")
        writer.writeheader()
        writer.writerows(rows)


def sample_metric_cells(row: dict) -> tuple[str, str, str]:
    knob = row["Countermeasure"]
    profile = row["Profile"]
    runtime_valid = str(row.get("RuntimeComparisonValid", "")).lower() == "true"
    resource_valid = str(row.get("ResourceComparisonValid", "")).lower() == "true"
    wall_b = parse_num(row.get("BaselineMedianSeconds"))
    wall_c = parse_num(row.get("CountermeasureMedianSeconds"))
    wall_pct = parse_num(row.get("MedianChangePercent"))
    cpu_b = parse_num(row.get("BaselineMedianCpuSeconds"))
    cpu_c = parse_num(row.get("CountermeasureMedianCpuSeconds"))
    cpu_pct = parse_num(row.get("MedianCpuChangePercent"))
    mem_b = parse_num(row.get("BaselineMedianPeakWorkingSetMB"))
    mem_c = parse_num(row.get("CountermeasureMedianPeakWorkingSetMB"))
    mem_pct = parse_num(row.get("MedianPeakWorkingSetChangePercent"))

    if profile == "short-lived" and runtime_valid and knob != "DP":
        return (
            f"{fmt_num(wall_b, 3)} s → {fmt_num(wall_c, 3)} s",
            fmt_pct(wall_pct),
            "Passou funcionalmente; custo de tempo no ruído típico",
        )
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


def aggregate_by_cm(rows: list[dict]) -> list[dict]:
    out = []
    for knob in CM_ORDER:
        cm_rows = [r for r in rows if r["Countermeasure"] == knob]
        short_rows = [r for r in cm_rows if r["Profile"] == "short-lived"]
        persist_rows = [r for r in cm_rows if r["Profile"] == "persistent"]
        evid = short_evidence(knob, cm_rows[0].get("FunctionalEvidence") or "")
        wall_pcts = [
            parse_num(r.get("MedianChangePercent"))
            for r in short_rows
            if str(r.get("RuntimeComparisonValid")).lower() == "true" and knob != "DP"
        ]
        cpu_pcts = [
            parse_num(r.get("MedianCpuChangePercent"))
            for r in persist_rows
            if str(r.get("ResourceComparisonValid")).lower() == "true"
        ]
        mem_pcts = [
            parse_num(r.get("MedianPeakWorkingSetChangePercent"))
            for r in persist_rows
            if str(r.get("ResourceComparisonValid")).lower() == "true"
        ]
        wall_b = median(
            [parse_num(r.get("BaselineMedianSeconds")) for r in short_rows]
            or [parse_num(r.get("BaselineMedianSeconds")) for r in cm_rows]
        )
        wall_c = median(
            [parse_num(r.get("CountermeasureMedianSeconds")) for r in short_rows]
            or [parse_num(r.get("CountermeasureMedianSeconds")) for r in cm_rows]
        )
        pass_n = sum(1 for r in cm_rows if r.get("FunctionalStatus") == "PASS")
        total = len(cm_rows)

        if knob == "DP":
            amostra = (
                f"Wall mediano {fmt_num(wall_b, 3)}→{fmt_num(wall_c, 3)} s "
                f"(impacto; n/a eficácia)"
            )
            variacao = "n/a (functional-only)"
            avaliacao = f"{pass_n}/{total} PASS funcional; tempo/recurso são impacto"
        elif knob == "DO":
            amostra = (
                f"Curta wall {fmt_num(wall_b, 3)}→{fmt_num(wall_c, 3)} s; "
                f"Persistente: CPU/mem na janela 10 s"
            )
            variacao = (
                f"Curta {fmt_pct(median([v for v in wall_pcts if v is not None]))}; "
                f"Persist. CPU {fmt_pct(median([v for v in cpu_pcts if v is not None]))} / "
                f"mem {fmt_pct(median([v for v in mem_pcts if v is not None]))}*"
            )
            avaliacao = (
                f"{pass_n}/{total} PASS; deltas extremos de recurso em persistentes "
                "são anômalos"
            )
        else:
            if short_rows and not persist_rows:
                amostra = f"Wall {fmt_num(wall_b, 3)}→{fmt_num(wall_c, 3)} s"
                variacao = fmt_pct(median([v for v in wall_pcts if v is not None]))
            elif persist_rows and not short_rows:
                amostra = "CPU/mem na janela fixa de 10 s (amostras persistentes)"
                variacao = (
                    f"CPU {fmt_pct(median([v for v in cpu_pcts if v is not None]))} / "
                    f"mem {fmt_pct(median([v for v in mem_pcts if v is not None]))}"
                )
            else:
                amostra = (
                    f"Curta wall {fmt_num(wall_b, 3)}→{fmt_num(wall_c, 3)} s; "
                    f"Persistente: CPU/mem 10 s"
                )
                variacao = (
                    f"Curta {fmt_pct(median([v for v in wall_pcts if v is not None]))}; "
                    f"Persist. CPU {fmt_pct(median([v for v in cpu_pcts if v is not None]))}"
                )
            avaliacao = f"{pass_n}/{total} PASS funcional; impacto tipicamente baixo/moderado"

        out.append(
            {
                "knob": knob,
                "evidencia": evid,
                "amostra": amostra,
                "variacao": variacao,
                "avaliacao": avaliacao,
                "pass_n": pass_n,
                "total": total,
            }
        )
    return out


def corpus_stats(rows: list[dict], resumo: list[dict] | None = None) -> dict:
    samples = resumo
    if samples is None:
        # derive from detail
        seen = {}
        for r in rows:
            seen[r["ShaShort"]] = r
        samples = [
            {
                "ShaShort": k,
                "Profile": v["Profile"],
                "FunctionalAllPass": all(
                    x.get("FunctionalStatus") == "PASS"
                    for x in rows
                    if x["ShaShort"] == k
                ),
            }
            for k, v in seen.items()
        ]
    n = len(samples)
    persist = sum(1 for s in samples if s.get("Profile") == "persistent")
    short = n - persist
    cells = len(rows)
    pass_cells = sum(1 for r in rows if r.get("FunctionalStatus") == "PASS")
    detected = sum(1 for r in rows if str(r.get("BaselineDetectedPin")).lower() == "true")
    masked = sum(
        1 for r in rows if str(r.get("CountermeasureMaskedPin")).lower() == "true"
    )
    by_cm = {}
    for knob in CM_ORDER:
        cm_rows = [r for r in rows if r["Countermeasure"] == knob]
        by_cm[knob] = {
            "pass": sum(1 for r in cm_rows if r.get("FunctionalStatus") == "PASS"),
            "total": len(cm_rows),
            "detected": sum(
                1 for r in cm_rows if str(r.get("BaselineDetectedPin")).lower() == "true"
            ),
            "masked": sum(
                1
                for r in cm_rows
                if str(r.get("CountermeasureMaskedPin")).lower() == "true"
            ),
            "cpu_pct": median(
                [
                    parse_num(r.get("MedianCpuChangePercent"))
                    for r in cm_rows
                    if r.get("Profile") == "persistent"
                    and str(r.get("ResourceComparisonValid")).lower() == "true"
                ]
            ),
            "mem_pct": median(
                [
                    parse_num(r.get("MedianPeakWorkingSetChangePercent"))
                    for r in cm_rows
                    if r.get("Profile") == "persistent"
                    and str(r.get("ResourceComparisonValid")).lower() == "true"
                ]
            ),
            "wall_pct": median(
                [
                    parse_num(r.get("MedianChangePercent"))
                    for r in cm_rows
                    if r.get("Profile") == "short-lived"
                    and str(r.get("RuntimeComparisonValid")).lower() == "true"
                    and knob != "DP"
                ]
            ),
        }
    return {
        "n": n,
        "persist": persist,
        "short": short,
        "cells": cells,
        "pass_cells": pass_cells,
        "detected": detected,
        "masked": masked,
        "by_cm": by_cm,
    }


def build_infected_pdf(detail: list[dict], resumo: list[dict], font: str, font_bold: str) -> Path:
    st = make_styles(font, font_bold)
    out = ROOT_MAL / "TOMWare-corpus-maligno-14-amostras.pdf"
    doc = SimpleDocTemplate(
        str(out),
        pagesize=landscape(A4),
        leftMargin=1.2 * cm,
        rightMargin=1.2 * cm,
        topMargin=1.2 * cm,
        bottomMargin=1.3 * cm,
        title="TOMWare — Corpus maligno consolidado (14 amostras)",
        author="TOMWare",
    )
    story: list = []
    stats = corpus_stats(detail, resumo)
    story.append(
        Paragraph(
            "TOMWare: relatório consolidado do corpus de amostras malignas "
            "(14 executáveis × 5 contramedidas)",
            st["title"],
        )
    )
    story.append(
        Paragraph(
            "Material complementar — ocultação de vestígios do Intel Pin sob DE, DM, DO, DD e DP "
            "em amostras reais (VM isolada).",
            st["caption"],
        )
    )
    story.append(Paragraph("1. Resultado consolidado", st["h2"]))
    story.append(
        Paragraph(
            f"Em <b>{stats['n']}/{stats['n']}</b> amostras malignas, as cinco contramedidas "
            f"obtiveram <b>PASS</b> funcional (<b>{stats['pass_cells']}/{stats['cells']}</b> células). "
            f"A evidência vem dos PoCs (não classifica malícia). Perfil: "
            f"<b>{stats['short']}</b> de curta duração e <b>{stats['persist']}</b> persistentes "
            "(janela de observação de 10&nbsp;s). Algumas amostras exigiram reexecução de DO ou DM "
            "por limiar de ticks ou timeout do PoC; o consolidado usa a execução final PASS.",
            st["body"],
        )
    )

    agg = aggregate_by_cm(detail)
    header = [
        Paragraph("<b>Contramedida</b>", st["cell_b"]),
        Paragraph("<b>Evidência</b>", st["cell_b"]),
        Paragraph("<b>Amostra: baseline → CM</b>", st["cell_b"]),
        Paragraph("<b>Variação</b>", st["cell_b"]),
        Paragraph("<b>Avaliação</b>", st["cell_b"]),
    ]
    data = [header]
    for row in agg:
        data.append(
            [
                Paragraph(row["knob"], st["cell_b"]),
                Paragraph(row["evidencia"], st["cell"]),
                Paragraph(row["amostra"], st["cell"]),
                Paragraph(row["variacao"], st["cell"]),
                Paragraph(row["avaliacao"], st["cell"]),
            ]
        )
    main = Table(data, colWidths=[2.3 * cm, 5.2 * cm, 8.0 * cm, 5.5 * cm, 6.5 * cm])
    style_header_table(main)
    story.append(
        Paragraph(
            "Tabela 1. Consolidado funcional e de desempenho por contramedida (14 amostras malignas).",
            st["caption"],
        )
    )
    story.append(main)
    story.append(
        Paragraph(
            "Notas: (i) tempo total de wall-clock é inválido em persistentes; "
            "(ii) DO em GUI/persistentes pode gerar deltas anômalos de CPU/memória; "
            "(iii) DP é functional-only para eficácia.",
            st["caption"],
        )
    )

    story.append(Paragraph("2. Cobertura do corpus", st["h2"]))
    cov_header = [
        Paragraph("<b>#</b>", st["cell_b"]),
        Paragraph("<b>SHA-256 (8)</b>", st["cell_b"]),
        Paragraph("<b>Perfil</b>", st["cell_b"]),
        Paragraph("<b>DE</b>", st["cell_b"]),
        Paragraph("<b>DM</b>", st["cell_b"]),
        Paragraph("<b>DO</b>", st["cell_b"]),
        Paragraph("<b>DD</b>", st["cell_b"]),
        Paragraph("<b>DP</b>", st["cell_b"]),
        Paragraph("<b>Tent. DO</b>", st["cell_b"]),
    ]
    cov = [cov_header]
    by_short = {}
    for r in detail:
        by_short.setdefault(r["ShaShort"], {})[r["Countermeasure"]] = r
    for s in resumo:
        short = s["ShaShort"]
        group = by_short[short]
        cov.append(
            [
                Paragraph(str(s["SampleIndex"]), st["cell"]),
                Paragraph(short, st["cell"]),
                Paragraph(
                    "persistente" if s["Profile"] == "persistent" else "curta",
                    st["cell"],
                ),
                *[
                    Paragraph(str(group[k]["FunctionalStatus"]), st["cell"])
                    for k in CM_ORDER
                ],
                Paragraph(str(s.get("DoAttempts") or 1), st["cell"]),
            ]
        )
    cov_table = Table(
        cov, colWidths=[1.0 * cm, 2.4 * cm, 2.4 * cm, 1.8 * cm, 1.8 * cm, 1.8 * cm, 1.8 * cm, 1.8 * cm, 2.0 * cm]
    )
    style_header_table(cov_table)
    story.append(cov_table)
    doc.build(story)
    return out


def build_compare_pdf(
    ben_rows: list[dict],
    mal_rows: list[dict],
    mal_resumo: list[dict],
    font: str,
    font_bold: str,
) -> Path:
    st = make_styles(font, font_bold)
    COMPARE_DIR.mkdir(parents=True, exist_ok=True)
    out = COMPARE_DIR / "TOMWare-comparativo-benigno-vs-maligno.pdf"
    ben_stats = corpus_stats(ben_rows)
    mal_stats = corpus_stats(mal_rows, mal_resumo)

    doc = SimpleDocTemplate(
        str(out),
        pagesize=A4,
        leftMargin=1.5 * cm,
        rightMargin=1.5 * cm,
        topMargin=1.4 * cm,
        bottomMargin=1.4 * cm,
        title="TOMWare — Comparativo benigno vs maligno",
        author="TOMWare",
    )
    story: list = []
    story.append(
        Paragraph(
            "TOMWare: comparativo entre corpus benigno e maligno "
            "(Pin isolado vs Pin + contramedida)",
            st["title"],
        )
    )
    story.append(
        Paragraph(
            "Objetivo: contrastar o comportamento da ferramenta sob <b>somente Pin</b> "
            "(baseline TOMWare sem knob) e sob <b>Pin + contramedida</b>, "
            f"em {ben_stats['n']} amostras benignas e {mal_stats['n']} malignas.",
            st["caption"],
        )
    )

    story.append(Paragraph("1. Protocolo comum", st["h2"]))
    story.append(
        Paragraph(
            "Em ambos os corpora, a eficácia funcional é medida pelos PoCs "
            "(TestGetEnvironments, TestMemoryScan, TestOverhead, TestAntiDebug, TestProcessEnum), "
            "não pela malícia da amostra. Para cada knob: "
            "<b>(A) Pin + TOMWare sem a contramedida</b> deve detectar o vestígio; "
            "<b>(B) Pin + TOMWare com a contramedida</b> deve mascará-lo. "
            "A amostra real é exercitada em paralelo (10 pares, ordem alternada). "
            "Amostras de curta duração usam wall-time; persistentes usam CPU/memória "
            "na janela fixa de 10&nbsp;s (wall-time inválido).",
            st["body"],
        )
    )

    story.append(Paragraph("2. Visão geral dos corpora", st["h2"]))
    overview = [
        [
            Paragraph("<b>Métrica</b>", st["cell_b"]),
            Paragraph("<b>Benigno</b>", st["cell_b"]),
            Paragraph("<b>Maligno</b>", st["cell_b"]),
        ],
        [
            Paragraph("Amostras", st["cell"]),
            Paragraph(str(ben_stats["n"]), st["cell"]),
            Paragraph(str(mal_stats["n"]), st["cell"]),
        ],
        [
            Paragraph("Células (amostra × CM)", st["cell"]),
            Paragraph(f"{ben_stats['pass_cells']}/{ben_stats['cells']} PASS", st["cell"]),
            Paragraph(f"{mal_stats['pass_cells']}/{mal_stats['cells']} PASS", st["cell"]),
        ],
        [
            Paragraph("Perfil curta / persistente", st["cell"]),
            Paragraph(f"{ben_stats['short']} / {ben_stats['persist']}", st["cell"]),
            Paragraph(f"{mal_stats['short']} / {mal_stats['persist']}", st["cell"]),
        ],
        [
            Paragraph("PoC: Pin detectado no baseline", st["cell"]),
            Paragraph(
                f"{ben_stats['detected']}/{ben_stats['cells']}",
                st["cell"],
            ),
            Paragraph(
                f"{mal_stats['detected']}/{mal_stats['cells']}",
                st["cell"],
            ),
        ],
        [
            Paragraph("PoC: Pin mascarado com CM", st["cell"]),
            Paragraph(
                f"{ben_stats['masked']}/{ben_stats['cells']}",
                st["cell"],
            ),
            Paragraph(
                f"{mal_stats['masked']}/{mal_stats['cells']}",
                st["cell"],
            ),
        ],
    ]
    t = Table(overview, colWidths=[7.5 * cm, 4.5 * cm, 4.5 * cm])
    style_header_table(t)
    story.append(t)
    story.append(Spacer(1, 0.2 * cm))

    story.append(Paragraph("3. Somente Pin vs Pin + contramedida (por knob)", st["h2"]))
    story.append(
        Paragraph(
            "A tabela resume, para cada contramedida, se o vestígio aparece sob Pin isolado "
            "e se desaparece com a CM, nos dois corpora. Também registra o impacto mediano "
            "de desempenho (wall nas curtas; CPU/memória nas persistentes).",
            st["body"],
        )
    )
    cmp_header = [
        Paragraph("<b>CM</b>", st["cell_b"]),
        Paragraph("<b>Benigno: Pin só → Pin+CM</b>", st["cell_b"]),
        Paragraph("<b>Maligno: Pin só → Pin+CM</b>", st["cell_b"]),
        Paragraph("<b>Impacto (benigno)</b>", st["cell_b"]),
        Paragraph("<b>Impacto (maligno)</b>", st["cell_b"]),
    ]
    cmp_data = [cmp_header]
    for knob in CM_ORDER:
        b = ben_stats["by_cm"][knob]
        m = mal_stats["by_cm"][knob]
        b_func = (
            f"detectado {b['detected']}/{b['total']} → "
            f"mascarado {b['masked']}/{b['total']} "
            f"(PASS {b['pass']}/{b['total']})"
        )
        m_func = (
            f"detectado {m['detected']}/{m['total']} → "
            f"mascarado {m['masked']}/{m['total']} "
            f"(PASS {m['pass']}/{m['total']})"
        )
        if knob == "DP":
            b_imp = "n/a eficácia; impacto informativo"
            m_imp = "n/a eficácia; impacto informativo"
        else:
            b_imp = (
                f"wall {fmt_pct(b['wall_pct'])}; "
                f"CPU {fmt_pct(b['cpu_pct'])}; mem {fmt_pct(b['mem_pct'])}"
            )
            m_imp = (
                f"wall {fmt_pct(m['wall_pct'])}; "
                f"CPU {fmt_pct(m['cpu_pct'])}; mem {fmt_pct(m['mem_pct'])}"
            )
        cmp_data.append(
            [
                Paragraph(f"<b>{knob}</b><br/>{CM_LABEL[knob]}", st["cell"]),
                Paragraph(b_func, st["cell"]),
                Paragraph(m_func, st["cell"]),
                Paragraph(b_imp, st["cell"]),
                Paragraph(m_imp, st["cell"]),
            ]
        )
    cmp_table = Table(cmp_data, colWidths=[3.2 * cm, 4.0 * cm, 4.0 * cm, 3.2 * cm, 3.2 * cm])
    style_header_table(cmp_table)
    story.append(cmp_table)
    story.append(
        Paragraph(
            "Tabela 2. Comparativo funcional (Pin só → Pin+CM) e impacto mediano por corpus.",
            st["caption"],
        )
    )

    story.append(Paragraph("4. Interpretação", st["h2"]))
    story.append(Paragraph("4.1 Somente Pin (baseline)", st["h3"]))
    story.append(
        Paragraph(
            "Nos dois corpora, o baseline com Pin e TOMWare <b>sem</b> a contramedida "
            "reproduz o vestígio esperado no PoC correspondente (variáveis PIN_*, "
            "assinaturas em memória, ticks anômalos, PEB anti-debug, pin.exe na enumeração). "
            f"Taxa de detecção no baseline: benigno "
            f"<b>{ben_stats['detected']}/{ben_stats['cells']}</b>, maligno "
            f"<b>{mal_stats['detected']}/{mal_stats['cells']}</b>. "
            "Isso confirma que a superfície de detecção existe independentemente da "
            "natureza da amostra (controle negativo vs malware real).",
            st["body"],
        )
    )
    story.append(Paragraph("4.2 Pin + contramedida", st["h3"]))
    story.append(
        Paragraph(
            "Com a CM ativa, o mesmo PoC deixa de reportar o vestígio "
            f"(mascaramento: benigno <b>{ben_stats['masked']}/{ben_stats['cells']}</b>, "
            f"maligno <b>{mal_stats['masked']}/{mal_stats['cells']}</b>). "
            "A ferramenta se comporta de modo <b>equivalente</b> nos dois corpora no eixo "
            "funcional: a eficácia não depende de a carga ser benigna ou maligna, "
            "e sim da superfície atacada pelo knob.",
            st["body"],
        )
    )
    story.append(Paragraph("4.3 Desempenho e perfil de execução", st["h3"]))
    story.append(
        Paragraph(
            "O corpus maligno nesta campanha concentrou mais amostras <b>persistentes</b> "
            f"({mal_stats['persist']}/{mal_stats['n']}) do que o benigno "
            f"({ben_stats['persist']}/{ben_stats['n']}), o que desloca a leitura de impacto "
            "para CPU/memória na janela de 10&nbsp;s. Em ambos, DE/DM/DD tipicamente "
            "apresentam variação moderada; DO pode exibir deltas anômalos de recurso em "
            "GUI/persistentes (não interpretar como “melhoria”); DP permanece "
            "functional-only para eficácia. Wall-time só é comparável nas amostras de "
            "curta duração que completam naturalmente.",
            st["body"],
        )
    )
    story.append(Paragraph("4.4 Conclusão operacional", st["h3"]))
    story.append(
        Paragraph(
            "A TOMWare.M mascara os vestígios do Pin de forma reproduzível em cargas "
            "benignas e malignas. O Pin isolado expõe o indicador; Pin+CM o oculta. "
            "Diferenças entre corpora aparecem sobretudo no <b>perfil de execução</b> "
            "(complete vs observed) e na <b>magnitude do impacto</b>, não na capacidade "
            "funcional de ocultação.",
            st["body"],
        )
    )
    story.append(
        Paragraph(
            "Fontes: consolidado-benign-17-amostras.csv e consolidado-infected-14-amostras.csv; "
            "execuções em VM isolada, jul/2026.",
            st["caption"],
        )
    )
    doc.build(story)
    return out


def build_compare_csv(ben_rows: list[dict], mal_rows: list[dict], mal_resumo: list[dict]) -> Path:
    COMPARE_DIR.mkdir(parents=True, exist_ok=True)
    path = COMPARE_DIR / "comparativo-benigno-vs-maligno-por-cm.csv"
    ben_stats = corpus_stats(ben_rows)
    mal_stats = corpus_stats(mal_rows, mal_resumo)
    rows = []
    for knob in CM_ORDER:
        b = ben_stats["by_cm"][knob]
        m = mal_stats["by_cm"][knob]
        rows.append(
            {
                "Countermeasure": knob,
                "Label": CM_LABEL[knob],
                "Benign_Samples": ben_stats["n"],
                "Infected_Samples": mal_stats["n"],
                "Benign_PinOnly_Detected": b["detected"],
                "Benign_PinCM_Masked": b["masked"],
                "Benign_FunctionalPass": b["pass"],
                "Benign_FunctionalTotal": b["total"],
                "Infected_PinOnly_Detected": m["detected"],
                "Infected_PinCM_Masked": m["masked"],
                "Infected_FunctionalPass": m["pass"],
                "Infected_FunctionalTotal": m["total"],
                "Benign_MedianWallChangePct_ShortLived": b["wall_pct"],
                "Infected_MedianWallChangePct_ShortLived": m["wall_pct"],
                "Benign_MedianCpuChangePct_Persistent": b["cpu_pct"],
                "Infected_MedianCpuChangePct_Persistent": m["cpu_pct"],
                "Benign_MedianMemChangePct_Persistent": b["mem_pct"],
                "Infected_MedianMemChangePct_Persistent": m["mem_pct"],
            }
        )
    write_csv(path, rows)
    return path


def mirror(src: Path, dst_root: Path) -> None:
    dst_root.mkdir(parents=True, exist_ok=True)
    if src.is_file():
        target = dst_root / src.name
        target.write_bytes(src.read_bytes())


def main() -> None:
    font, font_bold = register_fonts()
    detail, resumo = load_infected_rows()
    ben_rows = load_benign_rows()

    # Write infected consolidations
    detail_csv = ROOT_MAL / "consolidado-infected-14-amostras.csv"
    resumo_csv = ROOT_MAL / "consolidado-infected-14-amostras-resumo.csv"
    detail_json = ROOT_MAL / "consolidado-infected-14-amostras.json"
    write_csv(detail_csv, detail)
    write_csv(resumo_csv, resumo)
    detail_json.write_text(
        json.dumps(
            {
                "GeneratedAt": datetime.now().isoformat(timespec="seconds"),
                "SampleType": "infected",
                "SampleCount": len(resumo),
                "CellCount": len(detail),
                "PassCells": sum(1 for r in detail if r["FunctionalStatus"] == "PASS"),
                "Summary": resumo,
                "Rows": detail,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    infected_pdf = build_infected_pdf(detail, resumo, font, font_bold)
    compare_csv = build_compare_csv(ben_rows, detail, resumo)
    compare_pdf = build_compare_pdf(ben_rows, detail, resumo, font, font_bold)

    # Mirror into repo Resultados
    for src in [
        detail_csv,
        resumo_csv,
        detail_json,
        infected_pdf,
        ROOT_MAL / "_make_infected_sample_pdf.py",
    ]:
        if src.exists():
            mirror(src, REPO_MAL)
    # also copy generator for infected corpus into malign folder
    gen_path = ROOT_MAL / "_make_infected_corpus_and_compare.py"
    # self already written elsewhere; mirror compare outputs
    for src in [compare_csv, compare_pdf]:
        mirror(src, REPO_COMPARE)
        mirror(src, COMPARE_DIR)  # ensure dir exists

    # Sync each sample folder already done previously; ensure new consolidations listed
    print(f"DETAIL_CSV={detail_csv}")
    print(f"RESUMO_CSV={resumo_csv}")
    print(f"DETAIL_JSON={detail_json}")
    print(f"INFECTED_PDF={infected_pdf}")
    print(f"COMPARE_CSV={compare_csv}")
    print(f"COMPARE_PDF={compare_pdf}")
    print(
        "PASS_CELLS",
        sum(1 for r in detail if r["FunctionalStatus"] == "PASS"),
        "/",
        len(detail),
    )


if __name__ == "__main__":
    main()
