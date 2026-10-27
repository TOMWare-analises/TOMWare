#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""JCVHT point-by-point reviewer letter. Numbers from audited CSVs only.

Does not edit the article PDF. Does not submit. Does not commit.
"""
from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
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
OUT = HERE / "cartas"
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
WARN = colors.HexColor("#fff5f5")


def S():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle(name="T", fontName=BOLD, fontSize=13, leading=16, alignment=TA_CENTER, spaceAfter=4))
    s.add(ParagraphStyle(name="Sub", fontName=BODY, fontSize=8.5, leading=11, alignment=TA_CENTER, spaceAfter=8))
    s.add(ParagraphStyle(name="H", fontName=BOLD, fontSize=11, leading=14, spaceBefore=10, spaceAfter=4, textColor=NAVY))
    s.add(ParagraphStyle(name="H2", fontName=BOLD, fontSize=9.5, leading=12, spaceBefore=7, spaceAfter=3, textColor=BLUE))
    s.add(ParagraphStyle(name="B", fontName=BODY, fontSize=8.7, leading=11.4, alignment=TA_JUSTIFY, spaceAfter=3))
    s.add(ParagraphStyle(name="Lab", fontName=BODY, fontSize=8.5, leading=11.2, alignment=TA_LEFT, spaceBefore=1, spaceAfter=1, leftIndent=6))
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
    path.parent.mkdir(parents=True, exist_ok=True)
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


def story_en(st):
    a, b, c = "(a) Reviewer concern.", "(b) Response.", "(c) Manuscript change (location)."
    it = lambda *xs: item(st, a, b, c, *xs)
    story = [
        P(st, "Response to Reviewers", "T"),
        P(
            st,
            "Manuscript: TOMWare.M: Selective Pintool-Based Countermeasures against "
            "Anti-Instrumentation Techniques in Windows Executables<br/>"
            "Journal of Computer Virology and Hacking Techniques &nbsp;|&nbsp; "
            "Submission <font face='Courier'>c05a1271-d18d-468d-8c50-9dc8b6c10952</font><br/>"
            "Decision: major revision. Date of this letter: 26 October 2026.<br/>"
            "Each item: (a) concern, (b) evidence we have, (c) where the revised manuscript applies it.",
            "Sub",
        ),
        HRFlowable(width="100%", thickness=0.6, color=NAVY),
        P(
            st,
            "We thank the Editor and the Reviewer. This letter answers every comment with "
            "measurements from the isolated guest (snapshot <font face='Courier'>tomware_go</font>, "
            "Pin <b>3.28.98749</b>, campaign DLL SHA-256 starting <font face='Courier'>4BBC6270</font>). "
            "The revised manuscript applies the changes listed in (c) at the stated locations. "
            "TMW0 means Pin with TOMWare loaded and all five knobs off (<font face='Courier'>-q</font>); "
            "it is not bare Pin. EMPTY is Pin with an empty pintool. "
            "We do not mix the submitted 10 s / 31-PE tables with a later 60 s / 50+50 campaign unless the window is named. "
            "Practical recovery of suppressed malware behaviour is not demonstrated.",
        ),
        P(st, "Software and artefacts", "H"),
        P(
            st,
            "Guest login laboratory VM; one Pin at a time; host-only network. "
            "Timing raw file: <font face='Courier'>experiment/jcvht_revision/results/matched_timing_n30.csv</font> "
            "(SHA-256 prefix <font face='Courier'>76208218</font>; N=30, no attempt discarded). "
            "Use the conventional median (mean of the two central values when n is even) in "
            "<font face='Courier'>matched_timing_summary_conventional.csv</font>. "
            "Do not use <font face='Courier'>matched_timing_summary.csv</font> (it still stores the lower element of the central pair).",
        ),
        P(st, "Editor (Eric Filiol)", "H"),
        P(st, "E.1 -- Accurate results, no overstatement, limitations stated", "H2"),
    ]
    story += it(
        "Ensure results are accurately reported, overstated conclusions rewritten, and limitations fully explained; submit a point-by-point response.",
        "This letter is that response. We no longer attribute the old Table 6 reduction (4080 to 2081) solely to SkewMask. "
        "Remaining alive under Pin is not preserved malware behaviour. The 14-sample x 5-knob PASS table is an "
        "<b>oracle</b> result, not proof that those binaries exercised the five checks. "
        "Four candidate malware/benign case studies (23 Oct 2026) produced <b>no</b> extra file, stdout, or identified child tree -- "
        "so we do <b>not</b> claim practical recovery of hidden behaviour.",
        "Applied in the Abstract and the single Limitations subsection. "
        "The 14-sample table remains an oracle/compatibility result (caption note). "
        "The four unsuccessful case attempts are Table (case-study attempt) in the Discussion.",
    )
    story += [P(st, "Reviewer -- Major 1 (timing experiment)", "H"), P(st, "M1.1 -- Matched workload, all attempts, Pin without -go", "H2")]
    story += it(
        "Table 6 compared -go against -do, confounding artificial overhead with the countermeasure. "
        "Compare -go vs -go -do at fixed workload; also show ordinary Pin without -go. Report all attempts.",
        "Done on TestOverhead.exe, pre-fixed N=30, every attempt kept. Arms: TMW0 "
        "(Pin + TOMWare, knobs off, -q), GO (-go -q), GO_DO (-go -do -q). "
        "TMW0 is not ordinary / bare Pin. "
        "Conventional medians (ticks): TMW0 <b>2,433.285</b> (30/30 below 3,000); "
        "GO <b>3,083.210</b> (11/30 = 36.7%, Wilson 95% [21.9%, 54.5%]); "
        "GO_DO <b>2,104.770</b> (30/30, Wilson [88.6%, 100%]). "
        "GO min-max 2,722-3,845; GO_DO 2,073-2,146; TMW0 2,168-2,750. "
        "The old 9/31 re-execution cell is not used. "
        "The submitted -go vs -do pair (including any 49% reading of 4080 vs 2081) is confounded.",
        "The matched N=30 table is now the main timing result in the Evaluation (Table 1 below). "
        "The originally submitted -go versus -do table is moved to an appendix and labelled as confounded; "
        "its numbers are kept. Abstract: compensation <b>rate</b> 11/30 vs 30/30, not a binary 'effective'. "
        "Body sentences that treated the old cell as a SkewMask gain are replaced.",
    )
    story += [
        P(st, "Table 1. Timing oracle, TestOverhead.exe, fixed N=30, all attempts retained.", "Cap"),
        tbl(
            [
                ["Arm", "Knobs", "N", "Median ticks", "Min-max", "Below 3,000"],
                ["TMW0", "-q", "30", "2,433.285", "2,168-2,750", "30/30 (100%)"],
                ["GO (baseline)", "-go -q", "30", "3,083.210", "2,722-3,845", "11/30 (36.7%)"],
                ["GO_DO (treatment)", "-go -do -q", "30", "2,104.770", "2,073-2,146", "30/30 (100%)"],
            ],
            [1.45 * inch, 1.15 * inch, 0.45 * inch, 1.15 * inch, 1.15 * inch, 1.3 * inch],
        ),
        Spacer(1, 6),
        P(st, "M1.2 -- Sequential / concurrent / clock / early wait", "H2"),
    ]
    story += it(
        "Test sequential and concurrent waits, repeated clock reads, and an early-returning wait. "
        "If a coherent timeline cannot be guaranteed, state a limitation.",
        "Oracle TestConcurrentWaitsLogged (seq Sleep, two overlapping Sleeps, TickCount, alertable WaitOne) "
        "with per-event QPC and PID in <font face='Courier'>events.jsonl</font>. "
        "Without -go, N=5, 24 Oct 2026 (<font face='Courier'>waits_logged.csv</font>): <b>20/20 exit 0</b>, no 90 s timeout. "
        "Native 5/5: Join-wall median <b>213.678</b> ms &lt; seq <b>406.218</b> ms, alertable ~46 ms. "
        "EMPTY / TMW0 / -do: Join-wall medians 571.867 / 553.862 / 517.802 ms (longer than seq). "
        "That is <b>not</b> serialization: the two Sleep QPC intervals still intersect under Pin "
        "(median intersection ~207 / 212 / 196 ms; overlap fraction 0.70-0.99). "
        "The failed model is Join-wall &lt; seq, from thread-create/Join/JIT cost, not lost Sleep overlap. "
        "TickCount never ran backwards on the single pair (20/20); that does not prove general monotonicity. "
        "The native ~46 ms early WaitOne is lost under Pin (291-636 ms). WaitOne is not SleepEx. "
        "-do does not restore Join-wall &lt; seq. EMPTY is Pin + EmptyPinTool.dll, not Pin without a tool. "
        "SkewMask accumulates a process-wide offset (AccumulateSkewTicks). "
        "We do not claim a globally coherent clock under Pin.",
        "Applied in Section 5.5 and Table 1b below. We do not write that Pin serializes concurrent Sleeps or that SkewMask restores overlap geometry.",
    )
    story += [
        P(st, "Table 1b. Wait model, TestConcurrentWaitsLogged, N=5, no -go, 24 Oct 2026. Conventional medians (ms).", "Cap"),
        tbl(
            [
                ["Arm", "seq 2x200", "par wall", "TickCount+50", "WaitOne(500)"],
                ["NAT", "406.218", "213.678", "62", "45.867"],
                ["EMPTY (Pin+empty tool)", "433.421", "571.867", "62", "445.610"],
                ["TMW0 (-q)", "441.209", "553.862", "78", "441.411"],
                ["DO (-do -q)", "414.809", "517.802", "56", "383.428"],
            ],
            [1.8 * inch, 1.15 * inch, 1.15 * inch, 1.2 * inch, 1.35 * inch],
        ),
        Spacer(1, 6),
        P(st, "M1.3 -- Instrumented runs that timed out with empty stdout", "H2"),
    ]
    story += it(
        "Diagnose instrumented cases that ended with no output.",
        "Under -go / -go -do the same wait oracle hits collector timeout -2 in 90 s with empty stdout "
        "(<font face='Courier'>module32_waits.csv</font>). Cause: SimulateOverhead inserts 10,000 __nop before "
        "<b>every</b> instruction. That is the artificial-load generator used by TestOverhead, not a SkewMask crash "
        "and not a backward clock. TestOverhead itself completes under -go and -go -do (Table 1). "
        "The wait oracle is therefore reported without -go.",
        "One sentence in Section 5.5: -2 on TestConcurrentWaits + -go is SimulateOverhead timeout, not a SkewMask crash.",
    )
    story += [P(st, "Reviewer -- Major 2 (resource changes)", "H"), P(st, "M2 -- Explain CPU/WS, milestones, window, process tree", "H2")]
    story += it(
        "Table 9 reports very large WS/CPU reductions under SkewMask. Explain program behaviour, milestones, "
        "observation window, and process tree (parent vs child).",
        "Agreed that 'still running' is not 'the same work'. Two windows must stay labelled:<br/>"
        "(1) <b>This manuscript, Table 9</b>: 10 s, 31 PE. The published working-set reductions "
        "(about 87% / 74%) and CPU reductions (about 38% / 29%) belong only to that protocol; "
        "they are two different quantities, not two WS figures.<br/>"
        "(2) <b>Later 50+50 campaign</b> (same Pin 3.28.98749, DLL 4BBC6270, seed 705851366; persistent window <b>60 s</b>): "
        "SkewMask <b>lengthens</b> wall-clock. Benign persistent TMW_DO minus TMW0: +55,452 ms [30,685, 57,031]. "
        "Malicious persistent: +37,387 ms [26,146, 42,770] (n_pairs=23, not 25). "
        "WS TMW_DO-TMW0 benign P -3.2 MB [-58.3, +0.4] (CI includes 0); malicious P -22.7 MB [-94.9, -10.7]. "
        "CPU rises because the process stays scheduled. This is not a performance gain and does not replace Table 9.<br/>"
        "Four targeted runs (MAL_03, MAL_07, MAL_10, BEN_06) recorded new_files=0 and empty stdout. "
        "child_count under Pin is not a process tree (pin.exe leftovers). We therefore <b>cannot</b> attach named "
        "milestones or a parent/child tree to Table 9.",
        "Applied in the Table 9 caption (window named 10 s / 31 PE; percentages are not a gain) "
        "and in a new 60 s addendum table. No named milestone or per-PID tree was added; that gap remains.",
    )
    story += [P(st, "Reviewer -- Major 3 (practical benefit)", "H"), P(st, "M3 -- Check + branch + extra behaviour", "H2")]
    story += it(
        "Controlled detectors and corpus executions do not show that the 14 malware samples attempted the supported "
        "checks, nor that TOMWare recovered hidden behaviour. Provide a few case studies: identify the check, "
        "compare Pin-only vs countermeasure, show extra behaviour (unpack, config, file, registry, network).",
        "We agree. The oracle PASS table is not evidence that each malware sample implemented that check. "
        "A later module-counter dump (30 PE, different live-dump DLL) is only a <b>trace</b>: ProcessEnum 0/269, "
        "memcmp 0 PIN_ matches; SkewMask fired on BEN_06, MAL_03, MAL_07, MAL_10. That does not identify a check in the PE.<br/>"
        "On 23 Oct 2026 we ran those four binaries NAT / TMW0 / -do (60 s). Results "
        "(<font face='Courier'>case_studies_by_run.csv</font>):",
        "Applied in the Discussion and in Table 2 below. The manuscript states that practical recovery "
        "of suppressed malware behaviour is <b>not demonstrated</b>. "
        "The 14-sample table remains oracle/compatibility only.",
    )
    story += [
        P(st, "Table 2. Case-study attempt, 23 Oct 2026. Knob = -do. Timeout 60 s. new_files=0 and empty stdout on every row.", "Cap"),
        tbl(
            [
                ["Sample", "NAT", "TMW0 (-q)", "-do -q"],
                ["MAL_03", "timeout 60 s", "ACCESS_VIOLATION 0xC0000005 (35 s)", "timeout 64 s"],
                ["MAL_07", "exit 0 in 1.4 s", "ACCESS_VIOLATION 0xC0000005 (4 s)", "timeout 62 s"],
                ["MAL_10", "timeout 60 s", "timeout 64 s", "timeout 64 s"],
                ["BEN_06", "exit 3 in 1.0 s", "exit 3 in 3.8 s", "timeout 62 s"],
            ],
            [1.1 * inch, 1.7 * inch, 2.3 * inch, 1.55 * inch],
        ),
        P(
            st,
            "MAL_03 and MAL_10 already last the full window natively, so -do adds no extra artefact. "
            "MAL_07 / BEN_06 lasting longer under -do is the same wall-clock stretch already measured on the 60 s campaign; "
            "it is not unpack, a drop, a registry key, or a C2 attempt (network stays host-only). "
            "We do not treat 'still alive at 60 s' as a case study. Crashes are retained (0xC0000005), not discarded.",
            "Tiny",
        ),
        P(st, "Reviewer -- Major 4 (functional tests)", "H"),
        P(st, "M4.1 -- Module32 positive control", "H2"),
    ]
    story += it(
        "Module32 replacements lacked a positive control. Cover pass-through vs masked calls, correct enumeration "
        "termination, unrelated entries preserved.",
        "TestProcessEnum covers Process32* / GetModuleHandle*, not Module32. "
        "TestModule32.exe (Etapa 4) already showed termination + kernel32 (module_count=29, pinish=0 even without -dp). "
        "That did <b>not</b> prove a pinvm filter. On 24 Oct we added TestModule32Fixture: a copy of "
        "<font face='Courier'>version.dll</font> loaded as <font face='Courier'>%TEMP%\\pinvm.dll</font> "
        "(dummy name, not real Pin). <font face='Courier'>module32_fixture.csv</font>: "
        "NAT fixture_pinvm=1 pinish=1 count=32; TMW0 fixture_pinvm=1 pinish=1 count=31; "
        "-dp and -da fixture_pinvm=0 pinish=0 count=30; kernel32=1 and terminated=True on all four. "
        "Dedicated ProcessEnum file <font face='Courier'>processenum_base.csv</font>: "
        "NAT pin.exe=0 (no Pin); TMW0 pin.exe=3; -dp=0; -da=0.",
        "Applied as two addendum tables after the original TestProcessEnum table "
        "(Module32 fixture; dedicated pin.exe counts). The fixture is not a real Pin module.",
    )
    story += [P(st, "M4.2 -- memcmp family beyond memcmp", "H2")]
    story += it(
        "Cover pass-through versus masked calls on the supported memory-compare interfaces.",
        "InstMemcmpMask hooks 12 routines (memcmp, _memcmp, __acrt_memcmp, bcmp, memicmp, _memicmp, _memicmp_l, "
        "memcmp_s, wmemcmp, wmemcmp_s, RtlCompareMemory, RtlEqualMemory). TestMemoryScan calls memcmp only; "
        "base -q finds PIN_ strings, -dm reports PIN_=0. "
        "Session 1 (23 Oct, <font face='Courier'>memcmp_variants.csv</font>) reached memcmp and _memicmp then aborted "
        "with CLR 0xE0434352. Session 2 (24 Oct, try/catch, <font face='Courier'>memcmp_variants_v2.csv</font>) "
        "exercised three exports with no abort: memcmp, _memicmp, RtlCompareMemory -- "
        "native/TMW0 = PASS; -dm/-da = MASKED. "
        "RtlEqualMemory and wmemcmp = NOT_EXERCISED (EntryPointNotFoundException on ntdll / ucrt / msvcrt). "
        "The line memcmp_passthrough=SAME_BAD ret=0 compares 7 bytes of AAAAAAAA vs AAAAAAAB, which are equal by "
        "construction; it is not a failing pass-through and not a tool defect. We claim three APIs, not five.",
        "Applied as an addendum table after the original TestMemoryScan table. "
        "Three C# APIs are cited; wmemcmp and RtlEqualMemory remain NOT_EXERCISED. SAME_BAD is not cited as a defect.",
    )
    story += [P(st, "M4.3 -- Combined -da smoke test", "H2")]
    story += it(
        "Add a small -da test on the supported oracles.",
        "Done, exit 0 on all five (<font face='Courier'>04_oracles/from_vm/da_oracles.csv</font>): "
        "TestAntiDebug -gdb -da -q all zeros; TestProcessEnum pin.exe=0; TestGetEnvironments PIN_* =0; "
        "TestMemoryScan PIN_/pin.exe/pinvm/pinipc =0; TestOverhead 2,040.7 &lt; 3,000.",
        "The sentence that -da was not evaluated is replaced. "
        "A five-detector smoke-test table is added. -da does not enable -go and is not a 3,100-run campaign.",
    )
    story += [P(st, "Reviewer -- Minor comments", "H"), P(st, "m1 -- Reproducibility", "H2")]
    story += it(
        "Pin the repository to a release or commit; state the observation interval and corpus selection.",
        "Evaluated software: Pin 3.28.98749; TOMWare.dll SHA-256 prefix 4BBC6270; snapshot tomware_go; "
        "timing seed/file as above. A previously cited git short hash 3040df7 is <b>stale</b> relative to this letter; "
        "identify the build by the DLL hash, not that commit. "
        "Windows: this paper's complementary tables = <b>10 s</b> persistent / natural completion for short-lived. "
        "The 50+50 campaign = 60 s / 120 s -- label which table uses which. "
        "Corpus of the submitted paper: 17 benign + 14 malicious Windows PE in docs/avaliacao/ and experiment/corpus/; "
        "exclusions in exclusions.csv. We do not invent VirusTotal family names.",
        "Applied in Methods: Pin 3.28.98749, DLL prefix 4BBC6270, snapshot tomware_go, 10 s window for this paper. "
        "The stale hash 3040df7 is removed.",
    )
    story += [P(st, "m2 -- Repeated limitations; Table 8 spacing", "H2")]
    story += it(
        "Shorten repeated limitations; fix Table 8 spacing (TestProcessEnum overflowing).",
        "Editorial. Collapse duplicate limitation paragraphs into one subsection. Wrap the TestProcessEnum column.",
        "Applied as one Limitations subsection and a wrap of the Table 8 TestProcessEnum column. No new experiment.",
    )
    story += [P(st, "m3 -- Abstract", "H2")]
    story += it(
        "Revise the 'all five countermeasures' sentence after the corrected timing evidence.",
        "The five modules are selectively enabled and independently oracled. "
        "SkewMask's quantitative claim is the matched 11/30 vs 30/30 rate (Table 1), not the old -go vs -do cell "
        "and not the 10 s WS percentages.",
        "Applied in the Abstract: five selectively enabled, independently oracled modules; "
        "SkewMask claim is 11/30 vs 30/30; TMW0 is named as Pin + TOMWare with knobs off, not ordinary Pin.",
    )
    story += [
        P(st, "Sentences this revision must not contain", "H"),
        P(
            st,
            "155/155. 9/31 as a success rate. -87% or -38% as a gain. "
            "'SkewMask always hides Pin.' 'The malware used the five checks.' "
            "Superiority over Arancino (no bake-off; public Arancino is Pin 2.14 + 32-bit). "
            "Crash-exit for collector label 6,517 (that figure is an IEEE Access campaign label = exit unknown, "
            "not a JCVHT result). Mixing 10 s / 31 PE with 60 s / 50+50 as one protocol. "
            "A case-study claim for MAL_03 / MAL_07 / MAL_10 / BEN_06. "
            "TMW0 called 'ordinary Pin'. The old 49% / 4080-vs-2081 cell as this revision's result. "
            "'-da was not evaluated' left in the body.",
            "Tiny",
        ),
    ]
    return story


def story_pt(st):
    a, b, c = "(a) Preocupacao do revisor.", "(b) Resposta.", "(c) Alteracao no manuscrito (local)."
    it = lambda *xs: item(st, a, b, c, *xs)
    story = [
        P(st, "Resposta aos revisores", "T"),
        P(
            st,
            "Manuscrito: TOMWare.M &nbsp;|&nbsp; Journal of Computer Virology and Hacking Techniques<br/>"
            "Submissao <font face='Courier'>c05a1271-d18d-468d-8c50-9dc8b6c10952</font> &nbsp;|&nbsp; revisao major<br/>"
            "Carta de 26/10/2026. Versao PT para trabalho. A carta a enviar ao jornal e o PDF em ingles.<br/>"
            "Cada item: (a) preocupacao, (b) evidencia, (c) onde o manuscrito revisto aplica a alteracao.",
            "Sub",
        ),
        HRFlowable(width="100%", thickness=0.6, color=NAVY),
        P(
            st,
            "Agradecemos ao Editor e ao Revisor. Evidencia: guest isolado, snapshot <font face='Courier'>tomware_go</font>, "
            "Pin <b>3.28.98749</b>, DLL <font face='Courier'>4BBC6270</font>. "
            "O manuscrito revisto aplica as alteracoes de (c) nos locais indicados. "
            "TMW0 = Pin com TOMWare carregado e knobs desligados; nao e Pin nu. "
            "Nao misturar as tabelas submetidas (10 s / 31 PE) com a campanha posterior 60 s / 50+50 sem rotular a janela. "
            "A recuperacao pratica de comportamento de malware suprimido nao esta demonstrada.",
        ),
        P(st, "Software e artefactos", "H"),
        P(
            st,
            "N=30: <font face='Courier'>matched_timing_n30.csv</font> (prefixo SHA-256 <font face='Courier'>76208218</font>), "
            "todas as tentativas. Mediana convencional em "
            "<font face='Courier'>matched_timing_summary_conventional.csv</font>. "
            "Nao usar <font face='Courier'>matched_timing_summary.csv</font> (ainda tem o elemento inferior do par).",
        ),
        P(st, "Editor (Eric Filiol)", "H"),
        P(st, "E.1 -- Resultados exactos, sem overclaim, limitacoes", "H2"),
    ]
    story += it(
        "Garantir numeros correctos, reescrever conclusoes infladas, explicar limitacoes; carta ponto a ponto.",
        "Esta carta e essa resposta. A reducao antiga da Table 6 (4080 para 2081) nao e so SkewMask. "
        "Continuar vivo sob Pin nao e comportamento de malware preservado. A tabela 14 x 5 PASS e oraculo, "
        "nao prova de que esses PE usaram os cinco checks. Quatro case studies (23/10) sem ficheiro, stdout ou arvore -- "
        "nao afirmamos recuperacao pratica.",
        "Aplicado no Abstract e na unica subseccao de Limitacoes. "
        "A tabela dos 14 permanece oraculo/compatibilidade. "
        "As quatro tentativas sem marco estao na Tabela 2 (Discussao).",
    )
    story += [P(st, "Revisor -- Major 1 (timing)", "H"), P(st, "M1.1 -- Carga casada, todas as tentativas, Pin sem -go", "H2")]
    story += it(
        "A Table 6 comparou -go com -do. Pedido: -go vs -go -do; mais Pin sem -go; reportar todas as tentativas.",
        "Feito em TestOverhead.exe, N=30 fixo, nada descartado. Bracos TMW0 "
        "(Pin + TOMWare, knobs off, -q), GO (-go -q), GO_DO (-go -do -q). "
        "TMW0 nao e Pin comum. "
        "Medianas convencionais (ticks): TMW0 <b>2.433,285</b> (30/30 abaixo de 3.000); "
        "GO <b>3.083,210</b> (11/30 = 36,7%, Wilson 95% [21,9%; 54,5%]); "
        "GO_DO <b>2.104,770</b> (30/30, Wilson [88,6%; 100%]). "
        "GO min-max 2.722-3.845; GO_DO 2.073-2.146; TMW0 2.168-2.750. "
        "A celula 9/31 nao e usada. O par -go vs -do submetido (incluindo qualquer leitura de 49% de 4080 vs 2081) e confundido.",
        "A tabela N=30 e agora o resultado principal de timing na Avaliacao (Tabela 1). "
        "A Table 6 original vai para apendice, rotulada como confundida; os numeros mantem-se. "
        "Abstract: taxa 11/30 vs 30/30. As frases do corpo que liam a celula antiga como ganho foram substituidas.",
    )
    story += [
        P(st, "Tabela 1. Oraculo de timing, TestOverhead.exe, N=30, todas as tentativas.", "Cap"),
        tbl(
            [
                ["Braco", "Knobs", "N", "Mediana ticks", "Min-max", "Abaixo de 3.000"],
                ["TMW0", "-q", "30", "2.433,285", "2.168-2.750", "30/30 (100%)"],
                ["GO (base)", "-go -q", "30", "3.083,210", "2.722-3.845", "11/30 (36,7%)"],
                ["GO_DO (tratamento)", "-go -do -q", "30", "2.104,770", "2.073-2.146", "30/30 (100%)"],
            ],
            [1.5 * inch, 1.15 * inch, 0.45 * inch, 1.15 * inch, 1.15 * inch, 1.25 * inch],
        ),
        Spacer(1, 6),
        P(st, "M1.2 -- Esperas seq / concorrentes / relogio / alertavel", "H2"),
    ]
    story += it(
        "Testar esperas sequenciais e concorrentes, leituras repetidas de relogio e wait que regressa cedo. "
        "Se nao houver timeline coerente, declarar limitacao.",
        "TestConcurrentWaitsLogged sem -go, N=5, 24/10 (<font face='Courier'>waits_logged.csv</font> + events.jsonl): "
        "<b>20/20 exit 0</b>. Nativo: parede do Join <b>213,678</b> ms &lt; seq <b>406,218</b> ms, alertavel ~46 ms. "
        "EMPTY / TMW0 / -do: parede do Join 571,867 / 553,862 / 517,802 (maior que o seq). "
        "Nao e serializacao: os dois Sleep ainda se intersectam sob Pin (intersecao ~207 / 212 / 196 ms). "
        "O que falha e o modelo parede-do-Join &lt; seq. TickCount (um par) nao andou para tras; isso nao prova monotonicidade geral. "
        "WaitOne nativo ~46 ms perde-se sob Pin. WaitOne nao e SleepEx. EMPTY = Pin + EmptyPinTool, nao Pin sem tool. "
        "O -do nao restaura parede-do-Join &lt; seq. Nao afirmamos relogio global coerente sob Pin.",
        "Aplicado na seccao 5.5 e na Tabela 1b. Nao escrevemos que o Pin serializa os Sleep nem que o SkewMask restaura a geometria.",
    )
    story += [
        P(st, "Tabela 1b. Modelo de espera, TestConcurrentWaitsLogged, N=5, sem -go, 24/10/2026. Medianas convencionais (ms).", "Cap"),
        tbl(
            [
                ["Braco", "seq 2x200", "par wall", "TickCount+50", "WaitOne(500)"],
                ["NAT", "406,218", "213,678", "62", "45,867"],
                ["EMPTY (Pin+tool vazia)", "433,421", "571,867", "62", "445,610"],
                ["TMW0 (-q)", "441,209", "553,862", "78", "441,411"],
                ["DO (-do -q)", "414,809", "517,802", "56", "383,428"],
            ],
            [1.8 * inch, 1.15 * inch, 1.15 * inch, 1.2 * inch, 1.35 * inch],
        ),
        Spacer(1, 6),
        P(st, "M1.3 -- Instrumentados com timeout e stdout vazio", "H2"),
    ]
    story += it(
        "Diagnosticar corridas instrumentadas sem saida.",
        "-go / -go -do no mesmo oraculo: timeout -2 em 90 s, stdout vazio. Causa: SimulateOverhead mete 10.000 __nop "
        "antes de <b>cada</b> instrucao. Nao e crash do SkewMask. O TestOverhead completa sob -go e -go -do (Tabela 1). "
        "O oraculo de espera reporta-se sem -go.",
        "Uma frase na seccao 5.5: -2 no oraculo de espera com -go e timeout do SimulateOverhead, nao crash do SkewMask.",
    )
    story += [P(st, "Revisor -- Major 2 (recursos)", "H"), P(st, "M2 -- CPU/WS, marcos, janela, arvore", "H2")]
    story += it(
        "A Table 9 mostra quedas grandes de WS/CPU sob SkewMask. Explicar comportamento, marcos, janela e arvore.",
        "'Ainda a correr' nao e 'o mesmo trabalho'. Duas janelas, sempre rotuladas:<br/>"
        "(1) <b>Este artigo, Table 9</b>: 10 s, 31 PE. As reducoes de working set (cerca de 87% / 74%) "
        "e de CPU (cerca de 38% / 29%) sao so desse protocolo; sao grandezas diferentes, nao dois valores de WS.<br/>"
        "(2) <b>Campanha 50+50 posterior</b> (Pin 3.28.98749, DLL 4BBC6270, semente 705851366; persistente <b>60 s</b>): "
        "o SkewMask <b>estica</b> a parede. Benigno persistente TMW_DO-TMW0: +55.452 ms [30.685, 57.031]. "
        "Maligno persistente: +37.387 ms [26.146, 42.770] (n_pairs=23). "
        "WS TMW_DO-TMW0 benigno P -3,2 MB [-58,3, +0,4] (IC inclui 0); maligno P -22,7 MB [-94,9, -10,7]. "
        "CPU sobe porque o processo continua escalonado. Nao e ganho e nao substitui a Table 9.<br/>"
        "Quatro corridas (MAL_03, MAL_07, MAL_10, BEN_06): new_files=0, stdout vazio. "
        "child_count sob Pin nao e arvore. Sem marco nomeado para a Table 9.",
        "Aplicado na caption da Table 9 (janela 10 s / 31 PE; percentagens nao sao ganho) "
        "e numa tabela-adenda de 60 s. Sem marco nomeado nem arvore por PID; essa lacuna permanece.",
    )
    story += [P(st, "Revisor -- Major 3 (beneficio pratico)", "H"), P(st, "M3 -- Check + ramo + comportamento extra", "H2")]
    story += it(
        "Detectores e o corpus nao mostram que os 14 malware tentaram os checks, nem que o TOMWare recuperou comportamento. "
        "Pedir 2-4 case studies: identificar o check, Pin-only vs knob, artefacto extra.",
        "Concordamos. A tabela PASS e oraculo. Um dump posterior de contadores (30 PE, outra DLL) so rastreia: "
        "ProcessEnum 0/269, memcmp 0 match PIN_; Skew em BEN_06, MAL_03, MAL_07, MAL_10 -- nao identifica o check no PE.<br/>"
        "Em 23/10 corremos esses quatro NAT / TMW0 / -do (60 s). Ver Tabela 2 "
        "(<font face='Courier'>case_studies_by_run.csv</font>).",
        "Aplicado na Discussao e na Tabela 2. O manuscrito diz que a recuperacao pratica "
        "<b>nao esta demonstrada</b>. A tabela dos 14 permanece so oraculo/compatibilidade.",
    )
    story += [
        P(st, "Tabela 2. Tentativa de case study, 23/10/2026. Knob = -do. Timeout 60 s. new_files=0 e stdout vazio em todas as linhas.", "Cap"),
        tbl(
            [
                ["Amostra", "NAT", "TMW0 (-q)", "-do -q"],
                ["MAL_03", "timeout 60 s", "ACCESS_VIOLATION 0xC0000005 (35 s)", "timeout 64 s"],
                ["MAL_07", "exit 0 em 1,4 s", "ACCESS_VIOLATION 0xC0000005 (4 s)", "timeout 62 s"],
                ["MAL_10", "timeout 60 s", "timeout 64 s", "timeout 64 s"],
                ["BEN_06", "exit 3 em 1,0 s", "exit 3 em 3,8 s", "timeout 62 s"],
            ],
            [1.1 * inch, 1.7 * inch, 2.3 * inch, 1.55 * inch],
        ),
        P(
            st,
            "MAL_03 e MAL_10 ja duram a janela no nativo. MAL_07 / BEN_06 mais longos sob -do = o mesmo esticar de parede "
            "da campanha 60 s; nao e unpack, drop, registo nem C2. 'Ainda vivo aos 60 s' nao e case study. "
            "Os crashes 0xC0000005 ficam no CSV.",
            "Tiny",
        ),
        P(st, "Revisor -- Major 4 (testes funcionais)", "H"),
        P(st, "M4.1 -- Controlo positivo Module32", "H2"),
    ]
    story += it(
        "Faltava controlo positivo de Module32: pass-through vs mascara, termino da enumeracao, entradas nao relacionadas.",
        "TestProcessEnum cobre Process32*, nao Module32. TestModule32 (Etapa 4) ja tinha termino + kernel32, "
        "mas pinish=0 sem -dp nao prova filtro. Em 24/10, TestModule32Fixture carrega uma copia de version.dll "
        "como %TEMP%\\pinvm.dll (dummy, nao e Pin). NAT fixture_pinvm=1 count=32; TMW0=1 count=31; "
        "-dp e -da fixture_pinvm=0 count=30; kernel32=1 e terminated=True nos quatro. "
        "processenum_base.csv: NAT pin.exe=0; TMW0=3; -dp=0; -da=0.",
        "Aplicado em duas tabelas-adenda apos a tabela original de TestProcessEnum "
        "(fixture Module32; contagens pin.exe). O dummy nao e modulo real do Pin.",
    )
    story += [P(st, "M4.2 -- Familia memcmp", "H2")]
    story += it(
        "Cobrir pass-through vs mascara nas interfaces de comparacao de memoria suportadas.",
        "A tool hooka 12 rotinas. TestMemoryScan so chama memcmp. "
        "Sessao 1 (23/10): memcmp/_memicmp e depois CLR 0xE0434352. "
        "Sessao 2 (24/10, try/catch): memcmp, _memicmp e RtlCompareMemory -- NAT/TMW0=PASS, -dm/-da=MASKED. "
        "RtlEqualMemory e wmemcmp = NOT_EXERCISED (EntryPointNotFound). "
        "memcmp_passthrough=SAME_BAD ret=0 compara 7 bytes de AAAAAAAA vs AAAAAAAB, iguais por construcao -- "
        "nao e defeito da tool. Reivindicamos tres APIs, nao cinco.",
        "Aplicado como tabela-adenda apos a tabela original de TestMemoryScan. "
        "Tres APIs C# citadas; wmemcmp e RtlEqualMemory ficam NOT_EXERCISED. SAME_BAD nao e citado como defeito.",
    )
    story += [P(st, "M4.3 -- Fumaca -da", "H2")]
    story += it(
        "Pequeno teste -da nos oraculos suportados.",
        "Feito, exit 0 nos cinco (<font face='Courier'>da_oracles.csv</font>): AntiDebug zeros; ProcessEnum pin.exe=0; "
        "ambiente PIN_*=0; MemoryScan PIN_/pin.exe/pinvm/pinipc=0; TestOverhead 2.040,7 &lt; 3.000.",
        "A frase '-da nao foi avaliado' e substituida. Tabela de fumaca nos cinco detectores. "
        "-da nao liga -go e nao e campanha de 3.100 corridas.",
    )
    story += [P(st, "Revisor -- menores", "H"), P(st, "m1 -- Reprodutibilidade", "H2")]
    story += it(
        "Fixar commit/release; dizer a janela e a seleccao do corpus.",
        "Pin 3.28.98749; DLL 4BBC6270; snapshot tomware_go. O hash git 3040df7 citado antes esta <b>desactualizado</b> -- "
        "identificar pelo hash da DLL. Janela deste artigo: <b>10 s</b> persistente. Campanha 50+50: 60/120 s. "
        "Corpus submetido: 17+14 PE; exclusions.csv. Sem familias VirusTotal inventadas.",
        "Aplicado em Metodos: Pin 3.28.98749, prefixo DLL 4BBC6270, snapshot tomware_go, janela 10 s neste artigo. "
        "O hash 3040df7 e removido.",
    )
    story += [P(st, "m2 -- Limitacoes repetidas; Table 8", "H2")]
    story += it(
        "Encurtar limitacoes repetidas; corrigir espacamento da Table 8 (TestProcessEnum).",
        "Editorial. Uma subseccao de limitacoes. Ajustar a coluna TestProcessEnum.",
        "Aplicado como uma subseccao de Limitacoes e wrap da coluna TestProcessEnum da Table 8. Sem experiencia nova.",
    )
    story += [P(st, "m3 -- Abstract", "H2")]
    story += it(
        "Rever a frase 'as cinco contramedidas' apos o timing corrigido.",
        "Os cinco modulos ligam-se a escolha e tem oraculos proprios. A pretensao quantitativa do SkewMask e 11/30 vs 30/30 "
        "(Tabela 1), nao a celula antiga -go vs -do nem as percentagens de WS a 10 s.",
        "Aplicado no Abstract: cinco modulos seleccionaveis e oraculados em separado; "
        "pretensao do SkewMask = 11/30 vs 30/30; TMW0 nomeado como Pin + TOMWare com knobs off, nao Pin comum.",
    )
    story += [
        P(st, "Frases que esta revisao nao pode conter", "H"),
        P(
            st,
            "155/155. 9/31 como taxa de sucesso. -87% ou -38% como ganho. "
            "'O SkewMask esconde sempre o Pin.' 'O malware usou os cinco checks.' "
            "Superioridade sobre Arancino. 6.517 como crash (e exit unknown duma campanha IEEE, nao deste artigo). "
            "Misturar 10 s / 31 PE com 60 s / 50+50. Case study para MAL_03 / MAL_07 / MAL_10 / BEN_06. "
            "TMW0 chamado de Pin comum. A celula 49% / 4080-vs-2081 como resultado desta revisao. "
            "'-da nao foi avaliado' deixado no corpo.",
            "Tiny",
        ),
    ]
    return story


def build():
    st = S()
    en = OUT / "JCVHT_c05a1271_Response_to_Reviewers.pdf"
    pt = OUT / "JCVHT_c05a1271_Resposta_aos_Revisores.pdf"
    write_pdf(
        story_en(st),
        en,
        "Response to Reviewers -- TOMWare.M JCVHT c05a1271",
        "TOMWare.M authors",
        footer_fn("JCVHT c05a1271 -- response to reviewers -- 26 Oct 2026"),
    )
    write_pdf(
        story_pt(st),
        pt,
        "Resposta aos revisores -- TOMWare.M JCVHT c05a1271",
        "TOMWare.M authors",
        footer_fn("JCVHT c05a1271 -- resposta aos revisores -- 26/10/2026"),
    )
    root = HERE.parents[2]
    for src in (en, pt):
        dest = root / src.name
        dest.write_bytes(src.read_bytes())
        print("copied", dest)


if __name__ == "__main__":
    build()
