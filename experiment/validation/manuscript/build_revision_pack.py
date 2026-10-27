#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Etapa 10: regenerate EN/PT reviewer letters + Overleaf instruction PDF.

Numbers come from revision_gap_closure/09_values/MANUSCRIPT_VALUES.json.
Does not send anything to IEEE. Does not commit.
"""
from __future__ import annotations

import json
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    HRFlowable,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

HERE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[2]
VALUES = json.loads(
    (HERE.parents[1] / "results" / "oracles" / "manuscript_values.json").read_text(
        encoding="utf-8"
    )
)
FONTS = Path(r"C:\Windows\Fonts")
if (FONTS / "arial.ttf").exists():
    pdfmetrics.registerFont(TTFont("Body", str(FONTS / "arial.ttf")))
    pdfmetrics.registerFont(TTFont("Body-Bold", str(FONTS / "arialbd.ttf")))
    BODY, BOLD = "Body", "Body-Bold"
else:
    BODY, BOLD = "Times-Roman", "Times-Bold"

NAVY = colors.HexColor("#1a365d")
BLUE = colors.HexColor("#2c5282")
HEAD = colors.HexColor("#e2e8f0")


def S():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle(name="T", fontName=BOLD, fontSize=13, leading=16, alignment=TA_CENTER, spaceAfter=4))
    s.add(ParagraphStyle(name="Sub", fontName=BODY, fontSize=8.5, leading=11, alignment=TA_CENTER, spaceAfter=8))
    s.add(ParagraphStyle(name="H", fontName=BOLD, fontSize=11, leading=14, spaceBefore=10, spaceAfter=4, textColor=NAVY))
    s.add(ParagraphStyle(name="H2", fontName=BOLD, fontSize=9.5, leading=12, spaceBefore=7, spaceAfter=3, textColor=BLUE))
    s.add(ParagraphStyle(name="B", fontName=BODY, fontSize=8.7, leading=11.4, alignment=TA_JUSTIFY, spaceAfter=3))
    s.add(ParagraphStyle(name="Lab", fontName=BODY, fontSize=8.5, leading=11.2, alignment=TA_LEFT, spaceBefore=1, spaceAfter=1, leftIndent=8))
    s.add(ParagraphStyle(name="Cap", fontName=BODY, fontSize=7.5, leading=9.5, alignment=TA_CENTER, spaceBefore=2, spaceAfter=6))
    s.add(ParagraphStyle(name="Tiny", fontName=BODY, fontSize=7.5, leading=9.5, spaceAfter=3))
    return s


def P(st, text, k="B"):
    return Paragraph(text, st[k])


def item(st, a_lab, b_lab, c_lab, concern, response, action):
    return [
        P(st, f"<b>{a_lab}</b> {concern}", "Lab"),
        P(st, f"<b>{b_lab}</b> {response}", "Lab"),
        P(st, f"<b>{c_lab}</b> {action}", "Lab"),
        Spacer(1, 4),
    ]


def tbl(data, widths):
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, 0), BOLD),
                ("FONTNAME", (0, 1), (-1, -1), BODY),
                ("FONTSIZE", (0, 0), (-1, -1), 7.4),
                ("BACKGROUND", (0, 0), (-1, 0), HEAD),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )
    )
    return t


def footer_fn(label):
    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont(BODY, 8)
        canvas.drawString(0.75 * inch, 0.45 * inch, label)
        canvas.drawRightString(letter[0] - 0.75 * inch, 0.45 * inch, str(doc.page))
        canvas.restoreState()

    return footer


def write_pdf(story, path, title, author, foot):
    doc = SimpleDocTemplate(
        str(path),
        pagesize=letter,
        leftMargin=0.7 * inch,
        rightMargin=0.7 * inch,
        topMargin=0.6 * inch,
        bottomMargin=0.65 * inch,
        title=title,
        author=author,
    )
    doc.build(story, onFirstPage=foot, onLaterPages=foot)
    print("wrote", path)


# Official display strings (from MANUSCRIPT_VALUES + timing min/max recomputed 23/10)
T_GO, T_GODO, T_TMW0 = "3,083.210", "2,104.770", "2,433.285"
T_GO_PT, T_GODO_PT, T_TMW0_PT = "3.083,210", "2.104,770", "2.433,285"
# Malicious persistent wall-of-medians (ms): NAT / EMPTY / TMW0 / TMW_DP / TMW_DO / TMW_ALL
WALL_MP = ("60,669", "16,869", "15,304", "18,891", "60,670", "60,802")
WALL_MP_PT = ("60.669", "16.869", "15.304", "18.891", "60.670", "60.802")


def letter_story(st, lang):
    en = lang == "en"
    a, b, c = (
        ("(a) Reviewer concern.", "(b) Response.", "(c) Action in Overleaf.")
        if en
        else ("(a) Preocupacao do revisor.", "(b) Resposta.", "(c) Acao no Overleaf.")
    )
    it = lambda *xs: item(st, a, b, c, *xs)
    story = []
    if en:
        story += [
            P(st, "Response to Reviewers", "T"),
            P(
                st,
                "Manuscript Access-2026-38745 &nbsp;|&nbsp; IEEE Access<br/>"
                "One resubmission. Each item: (a) concern, (b) response, (c) Overleaf action.<br/>"
                "Numbers: <font face='Courier'>revision_gap_closure/09_values/MANUSCRIPT_VALUES.json</font> (23 Oct 2026).",
                "Sub",
            ),
        ]
    else:
        story += [
            P(st, "Resposta aos revisores", "T"),
            P(
                st,
                "Manuscrito Access-2026-38745 &nbsp;|&nbsp; IEEE Access<br/>"
                "Uma unica ressubmissao. Cada item: (a) preocupacao, (b) resposta, (c) acao no Overleaf.<br/>"
                "Versao PT para o colaborador. A carta oficial IEEE e o PDF em ingles.<br/>"
                "Numeros: <font face='Courier'>MANUSCRIPT_VALUES.json</font> (23/10/2026).",
                "Sub",
            ),
        ]
    story += [HRFlowable(width="100%", thickness=0.6, color=NAVY)]

    if en:
        story += [
            P(
                st,
                "We thank the Associate Editor and the six reviewers. Every numbered concern is answered with new "
                "evidence or an explicit, scoped limitation. Three artefacts replace the previous 31-binary / "
                "3,100-launch / 10 s corpus experiment:",
            ),
            P(
                st,
                "1. <b>Functional oracles</b> (guest, 22 Oct 2026): matched AntiDebug 3+3 "
                "(<font face='Courier'>04_oracles/from_vm/antidebug_n3.csv</font>); "
                "<font face='Courier'>-da</font> on all five oracles; Module32 / waits. "
                "Timing N=30 was <b>not</b> rerun (hash <font face='Courier'>76208218...</font>).",
            ),
            P(
                st,
                "2. <b>SkewMask timing oracle, fixed N=30, all attempts retained</b> on TestOverhead.exe. "
                f"GO median {T_GO} ticks (11/30 below 3,000); GO_DO {T_GODO} (30/30); TMW0 {T_TMW0} (30/30).",
            ),
            P(
                st,
                "3. <b>Corpus campaign</b>: 100 PE � 9 � 10 = <b>9,000/9,000</b> JSON, seed 705851366, Pin 3.28.98749, "
                "snapshot <font face='Courier'>tomware_go</font>. Ladder NAT / EMPTY / TMW0 / five modules / TMW_ALL. "
                "Windows: 120 s short-lived, 60 s persistent. Official tables: "
                "<font face='Courier'>09_values/MANUSCRIPT_VALUES.json</font> (audited), not the un-audited "
                "<font face='Courier'>processed/</font> folder alone.",
            ),
            P(
                st,
                "Overleaf must <b>replace</b> every 31 / 3,100 / 10 s / 155/155 / ?87.2% cell. "
                "The 6,517 collector labels are <b>exit code unknown</b>, not crashes.",
                "Tiny",
            ),
            P(st, "Reviewer 1", "H"),
            P(st, "R1.1 � AntiDebug was not matched", "H2"),
        ]
        story += it(
            "Baseline used ?gdb; treatment used ?dd without ?gdb.",
            "Matched oracle, N=3: <font face='Courier'>-gdb -q</font> reported BeingDebugged=1, NtGlobalFlag=1, "
            "IsDebuggerPresent=1 in 3/3 runs; <font face='Courier'>-gdb -dd -q</font> reported all zero in 3/3. "
            "NAT and TMW0 without ?gdb are negative controls (all zero). Scope: those two PEB fields plus the "
            "oracle�s IsDebuggerPresent readout. Corpus ?dd runs are not proof that a sample queried the PEB.",
            "Figure 2 / Table 4 = this matched pair. Do not label AntiDebug unvalidated.",
        )
        story += [P(st, "R1.2 � SkewMask timing selection bias", "H2")]
        story += it(
            "Nine of 31 checks were re-executed until the score fell below the threshold.",
            f"Replaced by pre-fixed N=30. GO: <b>11/30 (36.7%)</b>, median {T_GO} (2,722�3,845). "
            f"GO_DO: <b>30/30</b>, median {T_GODO} (2,073�2,146). TMW0: 30/30, median {T_TMW0}. "
            "The 9/31 figure must not appear. Corpus TMW_DO kept all 1,000 outcomes.",
            "Abstract and Table 4: compensation <b>rate</b> 11/30 vs 30/30, not a binary �effective.�",
        )
        story += [
            P(st, "Table 1. Timing oracle, fixed N=30, all attempts retained.", "Cap"),
            tbl(
                [
                    ["Arm", "Knobs", "N", "Median ticks", "Min�max", "Below 3,000"],
                    ["TMW0", "?q", "30", T_TMW0, "2,168�2,750", "30/30 (100%)"],
                    ["GO (baseline)", "?go ?q", "30", T_GO, "2,722�3,845", "11/30 (36.7%)"],
                    ["GO_DO (treatment)", "?go ?do ?q", "30", T_GODO, "2,073�2,146", "30/30 (100%)"],
                ],
                [1.4 * inch, 1.1 * inch, 0.5 * inch, 1.15 * inch, 1.15 * inch, 1.35 * inch],
            ),
            Spacer(1, 6),
            P(st, "R1.3 � No experimental benchmark against Arancino", "H2"),
        ]
        story += it(
            "Without a direct comparison, modularity remains an assertion.",
            "Architectural table only (Arancino, COBAI, Peekaboo). Public Arancino is Pin 2.14 + VS 2010 and 32-bit only. "
            "This campaign is Pin 3.28 and 100 PE <b>x64</b>. We do not claim superiority. Future work (after this "
            "resubmission): 32-bit oracles / optional 32-bit corpus on Pin 3.28 ia32, then a bake-off on a shared "
            "32-bit protocol. The 9,000-run campaign is not that bake-off.",
            "Keep Table 1 (related systems). �VIII: add the 32-bit / Arancino items; do not rank tools.",
        )
        story += [P(st, "R1.4 � Malicious corpus small and undocumented", "H2")]
        story += it(
            "Fourteen unclassified samples.",
            "RQ2 uses <b>100</b> PE (50+50; 25+25+25+25), all x64. "
            "<font face='Courier'>corpus.csv</font> lists SHA-256, source (Windows_Environment / MalwareBazaar, 2026-10-14), "
            "architecture, size, profile, targeted evasion (none / unverified). "
            "family_or_product is a <b>coarse label</b> (Console/GUI App; Trojan_Bazaar / Backdoor_Bazaar), not a VT family. "
            "We do not claim the malware implemented the five hooked checks (Etapa 5: ProcessEnum 0/269; memcmp 0 PIN_ matches).",
            "Replace every 17+14 / 31 / 3,100 / 155 sentence. Condensed Table 3; point to corpus.csv.",
        )
        story += [P(st, "R1.5 � Medians without CI; ?87.2% working set", "H2")]
        story += it(
            "Large SkewMask resource deltas may reflect altered execution, not a gain.",
            "Median of per-binary medians, IQR, bootstrap 95% CI (2,000; seed 705851366); Wilson on rates. "
            "Under the 60 s window SkewMask <b>increases</b> wall-clock (benign persistent TMW0 2.2 s ? TMW_DO 60.8 s; "
            "paired +55,452 ms [30,685, 57,031]). Survival: benign 8.0% ? 52.8%; malicious TMW0 32.8% ? TMW_DO 57.6%. "
            "WS TMW_DO?TMW0: benign P ?3.2 MB [?58.3, +0.4] (includes 0); malicious P ?22.7 MB [?94.9, ?10.7] (n_pairs=23). "
            "CPU rises because the process stays scheduled. Not a performance gain. Delete ?87.2 / ?38.5.",
            "Replace Table 7 with absolute paired deltas. Negative WS ? improvement.",
        )
        story += [P(st, "R1.6 � Narrow interception versus the title", "H2")]
        story += it(
            "NtQuerySystemInformation and RDTSC bypass the modules.",
            "Agreed. �Mitigating evasive techniques� means selected indicators on monitored interfaces.",
            "Keep the scoped �VIII. No transparency claim.",
        )
        story += [P(st, "Reviewer 2", "H"), P(st, "R2.1 � Share the matched AntiDebug rerun", "H2")]
        story += it("Rerun with ?gdb in both arms.", "Done (R1.1), 3+3, antidebug_n3.csv.", "See R1.1.")
        story += [P(st, "R2.2 � Fixed-N timing, retain all, CIs", "H2")]
        story += it(
            "Predefine repetitions; do not drop misses.",
            "Oracle N=30 all kept (Table 1). Corpus TMW_DO: 1,000 kept, bootstrap CIs.",
            "Do not write �SkewMask is effective� as a binary verdict.",
        )
        story += [P(st, "R2.3 � Native / empty / disabled-module baselines", "H2")]
        story += it(
            "Incremental-only baselines hide Pin�s cost versus native.",
            "Nine arms including NAT, EMPTY, TMW0. The 9,000-run campaign omitted bare Pin without ?t because that "
            "day�s probe failed (<font face='Courier'>pin_condition_valid=false</font>). An isolated probe on 22 Oct "
            "completed with exit 0 � we do <b>not</b> claim Pin-without-tool is always impossible. "
            "Benign short-lived median-of-medians wall-clock: NAT 0.26 s, EMPTY 1.48 s, TMW0 1.97 s, TMW_DP 5.53 s, "
            "TMW_DO 35.0 s, TMW_ALL 36.7 s.",
            "Baseline-ladder table in �VI. Strike future-work item 5.",
        )
        story += [P(st, "R2.4 � Auditable corpus table", "H2")]
        story += it(
            "SHA-256, source, family, packer, architecture, profile, evasion.",
            "Those columns exist. Family is coarse; malware targeted_evasion = unverified. No invented VT names.",
            "Condensed table in the paper.",
        )
        story += [P(st, "R2.5 � Arancino / COBAI / Peekaboo", "H2")]
        story += it(
            "State what is unique.",
            "Architectural table (R1.3). Evidenced distinction: independent knobs + nine-rung ladder + ?da on one protocol.",
            "No experimental ranking. Future work: shared 32-bit protocol.",
        )
        story += [P(st, "R2.6 � Behavioral fidelity", "H2")]
        story += it(
            "Add API traces, coverage, process activity.",
            "The 9,000 JSON have counters off. A later 120-run external observer (exit, stdout hash, children, new files; "
            "no FidelityProbe) found TMW0 vs TMW_ALL same exit+stdout in <b>22/30</b> pairs. This is not API or BBL equivalence.",
            "Compatibility stays operational. Keep fidelity as a limitation / future work item 4.",
        )
        story += [P(st, "R2.7 � Compatibility too weak", "H2")]
        story += it(
            "Completion or 10 s alive ? behavioural equivalence.",
            "155/155 @ 10 s is withdrawn. Persistent criterion = 60 s controlled_termination. "
            "Survival n=250, Wilson 95%: benign NAT 8.0% [5.2, 12.0], TMW_DO 52.8% [46.6, 58.9], TMW_ALL 56.4% [50.2, 62.4]; "
            "malicious NAT 54.4% [48.2, 60.5], EMPTY 32.4% [26.9, 38.4], TMW0 32.8%, TMW_DO 57.6%, TMW_ALL 64.0% [57.9, 69.7]. "
            "Short-lived protocol termination ?96.8% in every arm. The 6,517/9,000 dominant short-lived label is "
            "<b>exit code unknown</b> (collector bug), not a tool crash. Launch failures 251/9,000.",
            "<b>Delete 155/155.</b> Table 5 = outcome classes. Abstract must not say all combinations passed.",
        )
        story += [P(st, "R2 extra � combined mode; five checks; novelty", "H2")]
        story += it(
            "No ?da; no proof malware used the five techniques.",
            "TMW_ALL is in the 9,000-run tables and tracks TMW_DO on persistents (SkewMask dominates). "
            "Etapa 5 (different DLL, 30 PE): AntiDebug surface 269/269 is load-time PEB sanitize; ProcessEnum 0/269; "
            "memcmp 146 intercepts and 0 PIN_ matches. RQ2 stays operational.",
            "Add a TMW_ALL row. One sentence: the 100-sample table is not evidence each binary exercised the check.",
        )
        story += [P(st, "Reviewer 3 (minor)", "H")]
        story += [P(st, "R3.1 � Matched AntiDebug", "H2")]
        story += it("Match or label unvalidated.", "Matched 3+3 (R1.1).", "Do not label unvalidated.")
        story += [P(st, "R3.2 � 29% re-execution", "H2")]
        story += it("Explain the 29% (9/31).", "Old protocol only. Current: N=30, zero re-executions, 11/30 vs 30/30.", "Delete 29% from the abstract.")
        story += [P(st, "R3.3 � Uncertainty", "H2")]
        story += it("Add CIs or call results descriptive.", "Wilson + bootstrap. No p-value hunt.", "Label tables �descriptive with interval estimates.�")
        story += [P(st, "R3.4 � Related-systems table", "H2")]
        story += it("Concise comparison table.", "Already in the revision PDF (Table 1).", "Keep it.")
        story += [P(st, "R3.5 � Language", "H2")]
        story += it("Typos / spacing.", "Noted.", "Decimal points (not locale commas). Fix Table 8 wrap.")
        story += [P(st, "Reviewer 4", "H"), P(st, "R4.1 � Matched AntiDebug now, not future work", "H2")]
        story += it("Do the oracle.", "Done (R1.1).", "Remove from future work.")
        story += [P(st, "R4.2 � All timing outcomes; rate in abstract", "H2")]
        story += it("Fix N; report every outcome.", "Table 1; abstract 11/30 vs 30/30.", "No single �below threshold� verdict.")
        story += [P(st, "R4.3 � ?87.2% / ?38.5%", "H2")]
        story += it(
            "Largest effect may be a near-halt.",
            "The 60 s campaign is that test (R1.5). We adopt Reviewer 4�s reading: �still alive� is not compatibility.",
            "Delete ?87.2 / ?38.5.",
        )
        story += [P(st, "R4.4 � Prospective metric-validity rule", "H2")]
        story += it(
            "Wall-clock accepted for some modules and N/A for others, with no reconstructable rule.",
            "What <b>was</b> in experiment.config.json before the 9,000 runs: short-lived timeout 120 s; persistent "
            "window 60 s with controlled termination; 10 repetitions; failures/timeouts retained; no outcome-selected rerun; "
            "restore per block. What was <b>not</b> in the config: the resource filter <font face='Courier'>sample_count&gt;0</font> "
            "(applied post hoc in the audit). We say so. ProcessEnum wall-clock is cost (benign SL TMW_DP?TMW0 +3,844 ms). "
            "Launch failures (251) are recorded outcomes.",
            "Paste this distinction into �VI. Do not claim sample_count&gt;0 was a priori.",
        )
        story += [P(st, "R4 extra � native, figures, hooks, ?da", "H2")]
        story += it(
            "No native baseline; no hook counts; no ?da.",
            "NAT/EMPTY/TMW0/?da are in the 9,000-run ladder. Hook counters were off in those JSON. "
            "A 600-run diagnostic (other DLL) is reported as such and is not mixed with the 9,000.",
            "Normalize figure decimals.",
        )
        story += [P(st, "Reviewer 5", "H")]
        story += [P(st, "R5.1 � Debugger configurations", "H2")]
        story += it("Match debugger configs.", "Matched (R1.1).", "See R1.1.")
        story += [P(st, "R5.2 � Moderate behavioural-preservation claims", "H2")]
        story += it(
            "Compatibility ? equivalence of syscalls / CFG / effects.",
            "Agreed. Etapa 6: 22/30 pairs same exit+stdout under TMW0 vs TMW_ALL. The 6,517/9,000 label is unknown exit, not crash.",
            "Abstract and �VI-D: operational criteria ? behavioural equivalence.",
        )
        story += [P(st, "R5.3 � Performance may reflect state change", "H2")]
        story += it("Say results are descriptive.", "Done (R1.5). SkewMask wall-clock is the example.", "See Table 7 replacement.")
        story += [P(st, "R5.4 � References", "H2")]
        story += it("Add recent DBI-evasion papers.", "Optional. IEEE Access does not require reviewer-suggested cites.", "Add only papers the authors have read.")
        story += [P(st, "R5.5 � Scope of conclusions", "H2")]
        story += it(
            "Stay within oracles and corpus.",
            "Five oracles + 100 PE / nine conditions. No transparency, no Arancino win, no �malware used these five checks.�",
            "Keep that sentence in �VIII.",
        )
        story += [P(st, "Reviewer 6", "H")]
        story += [P(st, "R6.1 � AntiDebug configs differ", "H2")]
        story += it("Hard to interpret.", "Matched (R1.1).", "See R1.1.")
        story += [P(st, "R6.2 � Timing re-execution", "H2")]
        story += it("Selection bias.", "Fixed-N=30 (Table 1).", "See R1.2.")
        story += [P(st, "R6.3 � Weak operational compatibility", "H2")]
        story += it(
            "Criterion ? equivalence or transparency.",
            "155/155 removed; 60 s survival and exit-unknown mix reported (R2.7).",
            "No behavioural-equivalence claim.",
        )
        story += [P(st, "R6.4 � No native baseline; only medians", "H2")]
        story += it("Need native + CIs.", "NAT + EMPTY + Wilson/bootstrap (R2.3, R3.3).", "New ladder and interval tables.")
        story += [P(st, "R6.5 � Novelty versus existing frameworks", "H2")]
        story += it(
            "Novelty should be discussed and tested.",
            "Architectural table; no bake-off (R1.3). Novelty = modular evaluation + protocol. 32-bit/Arancino experiments after this resubmission.",
            "Do not claim an experimental ranking.",
        )
        story += corpus_tables(st, "en")
    else:
        story += pt_body(st, it)
        story += corpus_tables(st, "pt")
    return story


def pt_body(st, it):
    story = [
        P(
            st,
            "Agradecemos ao Editor Associado e aos seis revisores. Tres artefactos substituem o corpus de 31 / 3.100 / 10 s:",
        ),
        P(
            st,
            "1. Oraculos (22/10): AntiDebug 3+3 em antidebug_n3.csv; ?da nos cinco; Module32. Timing N=30 nao foi repetido.",
        ),
        P(
            st,
            f"2. Timing N=30: GO {T_GO_PT} (11/30); GO_DO {T_GODO_PT} (30/30); TMW0 {T_TMW0_PT} (30/30).",
        ),
        P(
            st,
            "3. Campanha 100 � 9 � 10 = 9.000 JSON, semente 705851366, Pin 3.28.98749. "
            "Tabelas oficiais: MANUSCRIPT_VALUES.json. Os 6.517 rotulos sao saida sem codigo, nao crash.",
        ),
        P(st, "Revisor 1", "H"),
        P(st, "R1.1 � AntiDebug nao casado", "H2"),
    ]
    story += it(
        "Base com ?gdb; tratamento com ?dd sem ?gdb.",
        "Oraculo casado N=3: ?gdb ?q 3/3 positivo; ?gdb ?dd ?q 3/3 zero. So esses campos PEB.",
        "Figura 2 / Tabela 4 = este par. Nao rotular AntiDebug como nao validado.",
    )
    story += [P(st, "R1.2 � Vies de selecao no timing", "H2")]
    story += it(
        "9/31 reexecutados ate passar.",
        f"N=30 prefixado. GO 11/30, mediana {T_GO_PT}; GO_DO 30/30, {T_GODO_PT}; TMW0 30/30, {T_TMW0_PT}. Sem 9/31.",
        "Abstract e Tabela 4: taxa 11/30 vs 30/30.",
    )
    story += [
        P(st, "Tabela 1. Oraculo de timing, N=30, todas as tentativas.", "Cap"),
        tbl(
            [
                ["Braco", "Knobs", "N", "Mediana", "Min�max", "Abaixo de 3.000"],
                ["TMW0", "?q", "30", T_TMW0_PT, "2.168�2.750", "30/30 (100%)"],
                ["GO", "?go ?q", "30", T_GO_PT, "2.722�3.845", "11/30 (36,7%)"],
                ["GO_DO", "?go ?do ?q", "30", T_GODO_PT, "2.073�2.146", "30/30 (100%)"],
            ],
            [1.3 * inch, 1.1 * inch, 0.5 * inch, 1.2 * inch, 1.2 * inch, 1.35 * inch],
        ),
        Spacer(1, 6),
        P(st, "R1.3 � Sem bake-off com Arancino", "H2"),
    ]
    story += it(
        "Sem comparacao direta, a modularidade e uma afirmacao.",
        "So tabela arquitetural. Arancino publico = Pin 2.14 + VS2010 + 32-bit. Campanha = Pin 3.28 e 100 PE x64. "
        "Sem superioridade. Depois do envio: testes 32-bit e bake-off em protocolo 32-bit partilhado.",
        "Manter Table 1. �VIII: acrescentar 32-bit / Arancino.",
    )
    story += [P(st, "R1.4 � Corpus pequeno", "H2")]
    story += it(
        "Catorze amostras sem familia.",
        "100 PE, 50+50, todos x64. Familia no CSV e rotulo grosso, nao VT. Sem �o malware usou os 5 checks�.",
        "Substituir 17+14 / 31 / 3.100 / 155.",
    )
    story += [P(st, "R1.5 � Sem IC; ?87,2% WS", "H2")]
    story += it(
        "Deltas grandes podem ser mudanca de estado.",
        "IC bootstrap/Wilson. SkewMask aumenta a parede (benigno persistente +55.452 ms). Apagar ?87,2 / ?38,5.",
        "Tabela 7 = deltas absolutos.",
    )
    story += [P(st, "R1.6 � Superficie estreita", "H2")]
    story += it("NtQuery / RDTSC escapam.", "Concordamos. Sem transparencia.", "Manter �VIII limitado.")
    story += [P(st, "Revisor 2", "H"), P(st, "R2.1�R2.2", "H2")]
    story += it("AntiDebug casado; N fixo no timing.", "Feito (R1.1, Tabela 1).", "Ver R1.1 e R1.2.")
    story += [P(st, "R2.3 � Bases NAT / EMPTY", "H2")]
    story += it(
        "Falta o custo do Pin vs nativo.",
        "Escada de nove bracos. Pin sem ?t omitido na campanha (probe falhou); probe isolado em 22/10 saiu 0. "
        "Nao afirmar que e sempre impossivel.",
        "Tabela de escada. Riscar future work item 5.",
    )
    story += [P(st, "R2.4 � Tabela do corpus", "H2")]
    story += it("Metadados auditaveis.", "SHA-256/fonte/x64/perfil sim; familia grosso; evasion unverified.", "Tabela resumida.")
    story += [P(st, "R2.5 � Arancino / COBAI / Peekaboo", "H2")]
    story += it("O que e unico?", "Knobs + escada + ?da. Sem ranking. Future work 32-bit.", "Sem bake-off nesta revisao.")
    story += [P(st, "R2.6 � Fidelidade", "H2")]
    story += it(
        "Traces de API / cobertura.",
        "9000 sem contadores. Observador externo 120 runs: TMW0 vs TMW_ALL iguais em 22/30 (exit+stdout). Sem equivalencia de API.",
        "Compatibilidade operacional.",
    )
    story += [P(st, "R2.7 � Compatibilidade fraca", "H2")]
    story += it(
        "10 s vivo ? equivalencia.",
        "155/155 retirado. Sobrevivencia 60 s (n=250). 6.517 = saida sem codigo, nao crash. Falhas 251.",
        "Apagar 155/155. Tabela 5 = classes.",
    )
    story += [P(st, "R2 extra � ?da e os cinco checks", "H2")]
    story += it(
        "Sem ?da; sem prova dos cinco checks.",
        "TMW_ALL nos 9000. Etapa 5: ProcessEnum 0/269; memcmp 0 match. RQ2 operacional.",
        "Linha TMW_ALL. Uma frase negativa sobre os checks.",
    )
    story += [P(st, "Revisor 3", "H")]
    story += it("AntiDebug / 29% / IC / tabela / lingua.", "3+3 feito; 9/31 so no protocolo antigo; Wilson+bootstrap.", "Apagar 29% do abstract.")
    story += [P(st, "Revisor 4", "H"), P(st, "R4.1�R4.3", "H2")]
    story += it("Fazer o oraculo; N fixo; explicar ?87%.", "Feito. Janela 60 s mostra que SkewMask estica, nao ganha.", "Apagar ?87,2 / ?38,5.")
    story += [P(st, "R4.4 � Regra de metrica", "H2")]
    story += it(
        "N/A sem regra.",
        "No config a priori: 120 s / 60 s / 10 reps / nao descartar falhas. sample_count&gt;0 e <b>post hoc</b> � dizemo-lo.",
        "Colar a distincao no �VI. Nao afirmar que sample_count estava no config.",
    )
    story += [P(st, "R4 extra", "H2")]
    story += it("NAT, hooks, ?da.", "Na escada dos 9000. Contadores off nesses JSON; diagnostico 600 e outra DLL.", "Normalizar decimais.")
    story += [P(st, "Revisor 5", "H")]
    story += it(
        "Preservacao comportamental; desempenho; ambito.",
        "22/30 exit+stdout iguais (Etapa 6). Sem transparencia / Arancino / cinco checks.",
        "Abstract e �VI-D: criterio operacional ? equivalencia.",
    )
    story += [P(st, "Revisor 6", "H")]
    story += it(
        "Configs, vies, compatibilidade, NAT, novidade.",
        "R1.1�R1.3 + escada + IC. Bake-off 32-bit depois do envio.",
        "Sem ranking experimental.",
    )
    return story


def corpus_tables(st, lang):
    if lang == "en":
        cap2 = "Table 2. Persistent window-survival, n=250, Wilson 95% CI."
        cap3 = "Table 3. Median of per-binary median wall-clock (ms)."
        cap4 = "Table 4. Paired treatment ? TMW0, bootstrap 95% CI."
        h2 = ["Group", "NAT", "EMPTY", "TMW0", "TMW_DO", "TMW_ALL"]
        r2a = ["Benign persistent", "8.0% [5.2, 12.0]", "11.2% [7.9, 15.7]", "9.6% [6.5, 13.9]", "52.8% [46.6, 58.9]", "56.4% [50.2, 62.4]"]
        r2b = ["Malicious persistent", "54.4% [48.2, 60.5]", "32.4% [26.9, 38.4]", "32.8% [27.3, 38.8]", "57.6% [51.4, 63.6]", "64.0% [57.9, 69.7]"]
        h3 = ["Stratum", "NAT", "EMPTY", "TMW0", "TMW_DP", "TMW_DO", "TMW_ALL"]
        rows3 = [
            ["Benign short-lived", "261", "1,485", "1,974", "5,534", "34,990", "36,695"],
            ["Benign persistent", "254", "2,180", "2,190", "6,094", "60,770", "60,746"],
            ["Malicious short-lived", "6,165", "10,332", "14,004", "13,747", "87,009", "91,086"],
            ["Malicious persistent", WALL_MP[0], WALL_MP[1], WALL_MP[2], WALL_MP[3], WALL_MP[4], WALL_MP[5]],
        ]
        h4 = ["Contrast", "Stratum", "? wall-clock (ms)", "? peak WS (MB)"]
        rows4 = [
            ["TMW_DP ? TMW0", "Benign SL", "+3,844 [3,427, 4,088]", "+0.5 [0.1, 1.0]"],
            ["TMW_DO ? TMW0", "Benign SL", "+31,669 [13,744, 51,072]", "+0.7 [?0.2, 2.2]"],
            ["TMW_DO ? TMW0", "Benign P", "+55,452 [30,685, 57,031]", "?3.2 [?58.3, +0.4]"],
            ["TMW_DO ? TMW0", "Malicious P (n_pairs=23)", "+37,387 [26,146, 42,770]", "?22.7 [?94.9, ?10.7]"],
            ["TMW_ALL ? TMW0", "Benign P", "+55,512 [38,005, 56,972]", "?5.1 [?74.6, 0.0]"],
            ["TMW_DM ? TMW0", "Malicious SL", "wall CI includes 0", "+0.451 [0.049, 0.805]"],
        ]
        tiny = "9,000 outcomes: exit-unknown 6,517; window 1,355; timeout 877; launch_failed 251. True crash in the 9,000: 0."
        forbid_h = "Do not write in Overleaf"
        forbid = (
            "� 155/155, 10 s window, 31 / 3,100 as the current protocol.<br/>"
            "� ?87.2% memory or ?38.5% CPU as a gain.<br/>"
            "� �SkewMask always hides Pin� (baseline 11/30).<br/>"
            "� �The 100 malware samples used the five checks.�<br/>"
            "� �TOMWare.M outperforms Arancino.�<br/>"
            "� Behavioural equivalence, transparency, or �short-lived runs are mostly crash-exit.�<br/>"
            "� sample_count&gt;0 was a priori in experiment.config.json."
        )
        head = "Corpus tables for Overleaf (do not invent other cells)"
    else:
        cap2 = "Tabela 2. Sobrevivencia persistente, n=250, IC Wilson 95%."
        cap3 = "Tabela 3. Mediana das medianas de wall-clock (ms)."
        cap4 = "Tabela 4. Contraste tratamento ? TMW0, IC bootstrap 95%."
        h2 = ["Grupo", "NAT", "EMPTY", "TMW0", "TMW_DO", "TMW_ALL"]
        r2a = ["Benigno persistente", "8,0% [5,2; 12,0]", "11,2% [7,9; 15,7]", "9,6% [6,5; 13,9]", "52,8% [46,6; 58,9]", "56,4% [50,2; 62,4]"]
        r2b = ["Maligno persistente", "54,4% [48,2; 60,5]", "32,4% [26,9; 38,4]", "32,8% [27,3; 38,8]", "57,6% [51,4; 63,6]", "64,0% [57,9; 69,7]"]
        h3 = ["Estrato", "NAT", "EMPTY", "TMW0", "TMW_DP", "TMW_DO", "TMW_ALL"]
        rows3 = [
            ["Benigno curto", "261", "1.485", "1.974", "5.534", "34.990", "36.695"],
            ["Benigno persistente", "254", "2.180", "2.190", "6.094", "60.770", "60.746"],
            ["Maligno curto", "6.165", "10.332", "14.004", "13.747", "87.009", "91.086"],
            ["Maligno persistente", WALL_MP_PT[0], WALL_MP_PT[1], WALL_MP_PT[2], WALL_MP_PT[3], WALL_MP_PT[4], WALL_MP_PT[5]],
        ]
        h4 = ["Contraste", "Estrato", "? parede (ms)", "? WS (MB)"]
        rows4 = [
            ["TMW_DP ? TMW0", "Benigno curto", "+3.844 [3.427; 4.088]", "+0,5 [0,1; 1,0]"],
            ["TMW_DO ? TMW0", "Benigno curto", "+31.669 [13.744; 51.072]", "+0,7 [?0,2; 2,2]"],
            ["TMW_DO ? TMW0", "Benigno persist.", "+55.452 [30.685; 57.031]", "?3,2 [?58,3; +0,4]"],
            ["TMW_DO ? TMW0", "Maligno persist. (n=23)", "+37.387 [26.146; 42.770]", "?22,7 [?94,9; ?10,7]"],
            ["TMW_ALL ? TMW0", "Benigno persist.", "+55.512 [38.005; 56.972]", "?5,1 [?74,6; 0,0]"],
            ["TMW_DM ? TMW0", "Maligno curto", "parede IC inclui 0", "+0,451 [0,049; 0,805]"],
        ]
        tiny = "9.000 desfechos: saida sem codigo 6.517; janela 1.355; timeout 877; launch_failed 251. Crash verdadeiro: 0."
        forbid_h = "Nao escrever no Overleaf"
        forbid = (
            "� 155/155, janela 10 s, 31 / 3.100 como protocolo atual.<br/>"
            "� ?87,2% memoria ou ?38,5% CPU como ganho.<br/>"
            "� �SkewMask esconde sempre o Pin.�<br/>"
            "� �Os 100 malware usaram os 5 checks.�<br/>"
            "� �TOMWare.M supera o Arancino.�<br/>"
            "� Equivalencia comportamental, transparencia, ou �curtos sao sobretudo crash-exit.�<br/>"
            "� sample_count&gt;0 estava a priori no experiment.config.json."
        )
        head = "Tabelas de corpus para o Overleaf (nao inventar celulas)"
    return [
        P(st, head, "H"),
        P(st, cap2, "Cap"),
        tbl([h2, r2a, r2b], [1.35 * inch, 1.25 * inch, 1.25 * inch, 1.25 * inch, 1.3 * inch, 1.3 * inch]),
        Spacer(1, 8),
        P(st, cap3, "Cap"),
        tbl([h3] + rows3, [1.45 * inch] + [0.85 * inch] * 6),
        Spacer(1, 8),
        P(st, cap4, "Cap"),
        tbl([h4] + rows4, [1.55 * inch, 1.45 * inch, 2.15 * inch, 1.95 * inch]),
        P(st, tiny, "Tiny"),
        P(st, forbid_h, "H"),
        P(st, forbid),
    ]


def overleaf_story(st):
    story = [
        P(st, "Overleaf instructions � Access-2026-38745", "T"),
        P(
            st,
            "Single instruction PDF for the collaborator. Official IEEE letter = English PDF. "
            "Do <b>not</b> upload to IEEE until the highlighted manuscript is checked against this pack.<br/>"
            "32-bit / Arancino experiments: after this resubmission (future work only).",
            "Sub",
        ),
        HRFlowable(width="100%", thickness=0.6, color=NAVY),
        P(st, "What to send together (to the Overleaf collaborator, not yet to reviewers)", "H"),
        P(
            st,
            "1. This file.<br/>"
            "2. <font face='Courier'>Access-2026-38745_Response_to_Reviewers.pdf</font> (English, official).<br/>"
            "3. <font face='Courier'>Access-2026-38745_Resposta_aos_Revisores.pdf</font> (Portuguese, helper).<br/>"
            "4. Optional: <font face='Courier'>MANUSCRIPT_REPLACEMENTS.md</font> and "
            "<font face='Courier'>09_values/FUTURE_WORK.md</font>.",
        ),
        P(st, "Replace in the .tex / Word source", "H"),
        P(
            st,
            "1. Entire abstract � N=30 rates 11/30 vs 30/30 with medians 3,083.210 / 2,104.770. "
            "100 PE, 9,000 launches, 60 s / 120 s. Compatibility ? equivalence. "
            "Do <b>not</b> write that short-lived runs are mostly crashes.<br/>"
            "2. Every 31 / 3,100 / 155 / 17+14 / 10 s sentence.<br/>"
            "3. Table 4 SkewMask: 11/30 vs 30/30; delete 9/31.<br/>"
            "4. Table 5: delete 155/155; paste letter Table 2 (60 s survival).<br/>"
            "5. Table 7: delete ?87.2 / ?38.5; paste letter Table 4 "
            "(malicious persistent TMW_DO = <b>+37,387 [26,146, 42,770]</b>, n_pairs=23; "
            "TMW_DM malicious SL WS +0.451 [0.049, 0.805]).<br/>"
            "6. �VI: 120 s / 60 s / NAT�EMPTY�TMW0 / seed 705851366. "
            "sample_count&gt;0 is <b>post hoc</b>.<br/>"
            "7. �VIII: strike items 4, 5, half of 7, N=30, AntiDebug 3+3. "
            "Add 32-bit Pin 3.28 ia32 and Arancino shared-protocol bake-off "
            "(<font face='Courier'>FUTURE_WORK.md</font>).<br/>"
            "8. Conclusion: no transparency, no Arancino win, no �malware used the five checks.�",
        ),
        P(st, "Highlight", "H"),
        P(st, "Yellow on every changed sentence, including the abstract. Then export a clean PDF+source."),
        P(st, "Do not mix", "H"),
        P(
            st,
            "IEEE 9,000-run campaign ? JCVHT paper. Oracles ? 100-PE corpus. "
            "Etapa 5 counters (other DLL) ? 9,000 JSON. Etapa 7 (1,800 exits) does not rewrite the 9,000.",
        ),
        P(st, "Stop conditions (do not submit if any remain)", "H"),
        P(
            st,
            "� 155/155, ?87.2, ?38.5, 9/31, 10 s as current protocol, 3,100 launches.<br/>"
            "� �crash-exit� as the meaning of the 6,517.<br/>"
            "� �sample_count&gt;0 was a priori.�<br/>"
            "� �TOMWare outperforms Arancino� or �malware used the five checks.�<br/>"
            "� Old letter numbers: timing medians 2,418 / 3,079; TMW_DO malicious P +37,057 [131, 42,770]; "
            "malicious persistent EMPTY wall-clock 13,266.",
        ),
        P(st, "After Overleaf export", "H"),
        P(
            st,
            "Send the new PDF back for the Etapa 11 check against MANUSCRIPT_VALUES.json. "
            "No git commit and no IEEE upload until that check and an explicit authorization.",
        ),
    ]
    return story


def build():
    st = S()
    en = HERE / "Access-2026-38745_Response_to_Reviewers.pdf"
    pt = HERE / "Access-2026-38745_Resposta_aos_Revisores.pdf"
    ov = HERE / "Access-2026-38745_Overleaf_Instructions.pdf"
    write_pdf(
        letter_story(st, "en"),
        en,
        "Access-2026-38745 Response to Reviewers",
        "TOMWare.M authors",
        footer_fn("Access-2026-38745 � Response to Reviewers"),
    )
    write_pdf(
        letter_story(st, "pt"),
        pt,
        "Access-2026-38745 Resposta aos revisores (PT)",
        "Autores TOMWare.M",
        footer_fn("Access-2026-38745 � Resposta aos revisores (PT)"),
    )
    write_pdf(
        overleaf_story(st),
        ov,
        "Access-2026-38745 Overleaf instructions",
        "TOMWare.M authors",
        footer_fn("Access-2026-38745 � Overleaf instructions (not for IEEE yet)"),
    )
    for src, name in (
        (en, "Access-2026-38745_Response_to_Reviewers.pdf"),
        (pt, "Access-2026-38745_Resposta_aos_Revisores.pdf"),
        (ov, "Access-2026-38745_Overleaf_Instructions.pdf"),
    ):
        dest = ROOT / name
        dest.write_bytes(src.read_bytes())
        print("wrote", dest)


if __name__ == "__main__":
    build()
