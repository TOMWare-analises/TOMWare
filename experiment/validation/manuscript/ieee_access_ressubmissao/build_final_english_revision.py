# -*- coding: utf-8 -*-
"""Build the English Access revision PDFs (clean + highlighted) and the letter.

The IEEE two-column .tex is not in this repository. The integral article is:
  22-page English base (SHA-256 CFD80F0D0EE9...) + addendum Tables 21-27
  and the replacement paragraphs that delete the Module32 / memcmp denials.
"""
from __future__ import annotations

import hashlib
import shutil
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    KeepTogether,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

HERE = Path(__file__).resolve().parent
OUT = HERE.parent
FONTS = Path(r"C:\Windows\Fonts")
USER_PDF = Path(
    r"c:\Users\marge\.cursor\projects\d-MMB-workspace-tomware-melhorias\attachments"
    r"\e1d52db9-dc78-4576-935d-7af5aafba8e0"
    r"\Mitigating_Evasive_Techniques_Against_Dynamic_Binary_Instrumentation"
    r"_with_Modular_Countermeasures__REVISION___1___1__1.pdf"
)
EXPECTED_SHA = "CFD80F0D0EE9"

if (FONTS / "arial.ttf").exists():
    pdfmetrics.registerFont(TTFont("Body", str(FONTS / "arial.ttf")))
    pdfmetrics.registerFont(TTFont("Body-Bold", str(FONTS / "arialbd.ttf")))
    pdfmetrics.registerFont(TTFont("Body-Italic", str(FONTS / "ariali.ttf")))
    BODY, BOLD, ITAL = "Body", "Body-Bold", "Body-Italic"
else:
    BODY, BOLD, ITAL = "Times-Roman", "Times-Bold", "Times-Italic"

NAVY = colors.HexColor("#1a365d")
YELLOW = colors.HexColor("#fff3bf")
LINE = colors.HexColor("#2c5282")
HEADER_BG = colors.HexColor("#edf2f7")


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def styles(hl: bool):
    s = getSampleStyleSheet()
    back = YELLOW if hl else colors.white
    s.add(ParagraphStyle(name="T", fontName=BOLD, fontSize=12, leading=15, alignment=TA_CENTER, spaceAfter=4, textColor=NAVY))
    s.add(ParagraphStyle(name="Sub", fontName=BODY, fontSize=8, leading=10, alignment=TA_CENTER, spaceAfter=8))
    s.add(ParagraphStyle(name="H", fontName=BOLD, fontSize=10.5, leading=13, spaceBefore=9, spaceAfter=3, textColor=NAVY))
    s.add(ParagraphStyle(name="H2", fontName=BOLD, fontSize=9.2, leading=12, spaceBefore=6, spaceAfter=2, textColor=LINE))
    s.add(ParagraphStyle(name="B", fontName=BODY, fontSize=8.6, leading=11.2, alignment=TA_JUSTIFY, spaceAfter=4))
    s.add(ParagraphStyle(name="N", fontName=BODY, fontSize=8.6, leading=11.2, alignment=TA_JUSTIFY, spaceAfter=4, backColor=back))
    s.add(ParagraphStyle(name="L", fontName=BODY, fontSize=8.2, leading=10.8, alignment=TA_LEFT, leftIndent=8, spaceAfter=1))
    s.add(ParagraphStyle(name="Cap", fontName=ITAL, fontSize=7.6, leading=9.6, alignment=TA_JUSTIFY, spaceBefore=2, spaceAfter=6, textColor=colors.HexColor("#2d3748")))
    s.add(ParagraphStyle(name="Cell", fontName=BODY, fontSize=7.2, leading=9.2))
    s.add(ParagraphStyle(name="CellB", fontName=BOLD, fontSize=7.2, leading=9.2))
    s.add(ParagraphStyle(name="Pre", fontName="Courier", fontSize=7.2, leading=9.0, spaceAfter=6, backColor=back if hl else colors.HexColor("#f7fafc")))
    return s


def esc(t: str) -> str:
    t = t.replace("**", "").replace("`", "")
    t = t.replace("$n=", "n=").replace("$N=", "N=")
    t = t.replace("$", "")
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def P(st, key, text, new=False):
    return Paragraph(esc(text), st["N"] if new else st["B"])


def make_table(st, header, rows, col_widths):
    head = [Paragraph(esc(c), st["CellB"]) for c in header]
    body = []
    for row in rows:
        body.append([Paragraph(esc(str(c)), st["Cell"]) for c in row])
    data = [head] + body
    tbl = Table(data, colWidths=col_widths, hAlign="LEFT")
    tbl.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), HEADER_BG),
                ("TEXTCOLOR", (0, 0), (-1, 0), NAVY),
                ("FONTNAME", (0, 0), (-1, 0), BOLD),
                ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#a0aec0")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7fafc")]),
            ]
        )
    )
    return tbl


def addendum_story(st):
    s = []
    s.append(Paragraph("Access-2026-38745 — English revision addendum", st["T"]))
    s.append(
        Paragraph(
            "Integral article = 22-page English base PDF (SHA-256 CFD80F0D0EE9…) + these pages. "
            "Tables 1–20 keep their numbers. New material is Tables 21–27. Yellow marks new or replacement text. "
            "Not IEEE two-column Overleaf output. Collaborator pack; not the journal upload.",
            st["Sub"],
        )
    )

    s.append(Paragraph("Deletes in the English base (V-B, V-D, VI-C, VII-A)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "The English CFD80 PDF is the source. Portuguese evaluation pages from the older 5CBC file are not used. "
            "Delete four denials: (1) V-B, no Module32 positive control; (2) V-D, InstMemcmpMask restricted to memcmp; "
            "(3) VI-C, absence of monitored modules is not a positive control; (4) VII-A, absence of target modules "
            "prevents confirmation of Module32 filtering. Paste the replacements below.",
            True,
        )
    )

    s.append(Paragraph("V-B ProcessEnum — Module32 fixture (after Table 6)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "The process oracle TestProcessEnum.exe used Unicode process enumeration and found three pin.exe entries "
            "under -q and none under -dp or -da (Table 6; one execution per configuration). A separate positive control "
            "exercised Module32 filtering (module32_fixture.csv). A copy of C:\\Windows\\System32\\version.dll was loaded "
            "as %TEMP%\\pinvm.dll. That file is a dummy name; it is not the real Pin module. Native and TMW0 enumerated "
            "the fixture. With -dp -q and -da -q the fixture name was hidden. kernel32.dll remained visible. Enumeration "
            "terminated (ENUM_OK). Counts: 32 / 31 / 30 / 30. The fixture does not validate NtQuerySystemInformation and "
            "does not individually validate every GetModuleHandleA/W calling pattern.",
            True,
        )
    )
    s.append(
        KeepTogether(
            [
                make_table(
                    st,
                    ["Configuration", "Knobs", "Exit", "Modules", "kernel32.dll", "fixture pinvm.dll"],
                    [
                        ["Native", "—", "0", "32", "visible", "visible"],
                        ["TMW0", "-q", "0", "31", "visible", "visible"],
                        ["ProcessEnum", "-dp -q", "0", "30", "visible", "hidden"],
                        ["Combined", "-da -q", "0", "30", "visible", "hidden"],
                    ],
                    [1.4 * inch, 0.9 * inch, 0.7 * inch, 0.9 * inch, 1.2 * inch, 1.4 * inch],
                ),
                Paragraph(
                    "TABLE 21. Module32 positive control. Dummy %TEMP%\\pinvm.dll is a copy of version.dll, not a real Pin module. Source: module32_fixture.csv. Campaign DLL 4BBC6270.",
                    st["Cap"],
                ),
            ]
        )
    )

    s.append(Paragraph("Combined -da smoke test (not ten repetitions)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "The filename da_n10.csv belongs to campaign id t2_n10_v7b. It contains five rows, one execution per oracle, "
            "not ten repetitions of combined mode. All five oracles exited 0. TestOverhead.exe scored 2042.56 < 3000. "
            "This smoke test does not prove the absence of module interactions on the 100-binary corpus. TMW_ALL in "
            "Table 19 is a separate operational arm.",
            True,
        )
    )
    s.append(
        KeepTogether(
            [
                make_table(
                    st,
                    ["Oracle", "Knobs", "Exit", "Timed out", "Duration (ms)"],
                    [
                        ["TestAntiDebug", "-gdb -da -q", "0", "no", "10316"],
                        ["TestProcessEnum", "-da -q", "0", "no", "13413"],
                        ["TestGetEnvironments", "-da -q", "0", "no", "13324"],
                        ["TestMemoryScan", "-da -q", "0", "no", "44062"],
                        ["TestOverhead", "-da -q", "0", "no", "14658"],
                    ],
                    [1.8 * inch, 1.4 * inch, 0.7 * inch, 1.0 * inch, 1.3 * inch],
                ),
                Paragraph(
                    "TABLE 22. Combined-mode smoke test (-da). One execution per oracle. Campaign DLL 4BBC6270.",
                    st["Cap"],
                ),
            ]
        )
    )

    s.append(Paragraph("InstMemcmpMask family (keep Table 12)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "Keep Table 12 memcmp signature counts. On campaign DLL 4BBC6270, intercepted PIN-string comparisons were "
            "PASS under native and TMW0 and MASKED under -dm -q and -da -q for memcmp, _memicmp, and RtlCompareMemory. "
            "Legitimate equality and inequality (pass-through) remained OK. RtlEqualMemory, wmemcmp, memcmp_s, "
            "wmemcmp_s, and bcmp were ABSENT / NOT_EXERCISED. They are implemented in the Pintool but were not "
            "individually validated. _memicmp_l is FOUND in msvcrt. Native and TMW0: PASS. Under -dm and -da the "
            "PIN-string path printed MASKED and the pass-through aborted with RECEIVED_ACCESS_FAULT at "
            "0xffffffffffffffff (exit 2; three-argument hook versus four-argument CRT). Later DLL D55EC952 does not "
            "retroactively validate the 9,000 attempts.",
            True,
        )
    )
    s.append(
        KeepTogether(
            [
                make_table(
                    st,
                    ["Configuration", "Exit", "memcmp PIN", "_memicmp PIN", "RtlCompareMemory PIN"],
                    [
                        ["Native", "0", "PASS (ret=0)", "PASS (ret=0)", "PASS (n=4)"],
                        ["TMW0 -q", "0", "PASS", "PASS", "PASS"],
                        ["-dm -q", "2", "MASKED (ret=1)", "MASKED (ret=1)", "MASKED (n=0)"],
                        ["-da -q", "2", "MASKED", "MASKED", "MASKED"],
                    ],
                    [1.4 * inch, 0.7 * inch, 1.5 * inch, 1.5 * inch, 1.7 * inch],
                ),
                Paragraph(
                    "TABLE 23. Comparison-family controls, campaign DLL 4BBC6270, memcmp_n10.csv, one execution per configuration.",
                    st["Cap"],
                ),
            ]
        )
    )

    s.append(Paragraph("Section VI — 22/30 diagnostic (not Introduction-only)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "A separate diagnostic, not part of the 9,000-attempt corpus, compared TMW0 (-q) with TMW_ALL (-da) under "
            "an external observer (external_ps). The observer recorded the process exit code and the SHA-256 of standard "
            "output. It did not record API traces, code coverage, or kernel events. Guest timeout 45 s. Ten executables "
            "(BEN_05, BEN_06, BEN_10, BEN_12, BEN_14, MAL_01, MAL_02, MAL_06, MAL_07, MAL_11) × three repetitions = "
            "30 pairs. Agreement: equal exit code and equal stdout SHA-256. Result: 22 of 30 agreed; 8 disagreed. "
            "This is not API equivalence. Per-binary hook counters were not collected in the 9,000 JSON.",
            True,
        )
    )
    s.append(
        KeepTogether(
            [
                make_table(
                    st,
                    ["Pairs", "TMW0", "TMW_ALL", "Reading"],
                    [
                        ["22/30", "—", "—", "exit and stdout hash equal"],
                        ["BEN_06 × 3", "exit 3", "timeout (−2)", "combined mode changed the outcome"],
                        ["BEN_12 × 2", "exit 0, 754 B stdout", "timeout; finished attempt same hash", "text matched when the process exited"],
                        ["MAL_06 × 1", "exit 0", "exit 2", "one of three repetitions differed"],
                        ["MAL_07 × 2", "exit 0", "0xC0000005", "combined mode worsened termination"],
                    ],
                    [1.2 * inch, 1.5 * inch, 2.0 * inch, 2.1 * inch],
                ),
                Paragraph(
                    "TABLE 24. External-observer diagnostic, TMW0 versus TMW_ALL, 10 executables × 3 repetitions. Source: fidelity_by_run.csv.",
                    st["Cap"],
                ),
            ]
        )
    )

    s.append(Paragraph("VI-B Baselines NAT / EMPTY / TMW0 and Pin without a Pintool", st["H"]))
    s.append(
        P(
            st,
            "N",
            "Two contrasts are separated. Total instrumentation cost is NAT versus EMPTY or TMW0. Incremental "
            "countermeasure effect is TMW0 versus the enabled module. TMW0 versus a module is not the total cost of "
            "Intel Pin. Short-lived benign binaries (n=25), median of per-binary medians from stratum_medians.csv: "
            "NAT 0.260 s, EMPTY 1.485 s, TMW0 1.973 s.",
            True,
        )
    )
    s.append(
        KeepTogether(
            [
                make_table(
                    st,
                    ["Condition", "Meaning", "Median wall-clock (s)"],
                    [
                        ["NAT", "no Pin", "0.260"],
                        ["EMPTY", "Pin + EmptyPinTool", "1.485"],
                        ["TMW0", "Pin + TOMWare, knobs off", "1.973"],
                    ],
                    [1.3 * inch, 2.6 * inch, 2.0 * inch],
                ),
                Paragraph(
                    "TABLE 26. Descriptive median wall-clock, short-lived benign binaries (n=25). Incremental effects remain Table 20.",
                    st["Cap"],
                ),
            ]
        )
    )
    s.append(
        P(
            st,
            "N",
            "An isolated probe of Pin without a Pintool (pin.exe -- TestAntiDebug.exe, 22 Oct 2026, pin_probe.csv) "
            "completed with exit code 0, empty stderr, and oracle stdout reporting no PEB anomaly. The CSV still "
            "records pin_condition_valid=False because of the campaign-day IPC/StartServer note. The 9,000-attempt "
            "campaign omitted the PIN arm (campaign.json). EMPTY remains the smallest Pin-hosted reference in those "
            "9,000 attempts. Do not claim that Pin without a Pintool is always impossible on Pin 3.28.",
            True,
        )
    )
    s.append(
        KeepTogether(
            [
                make_table(
                    st,
                    ["Field", "Value"],
                    [
                        ["command", "pin.exe -- TestAntiDebug.exe"],
                        ["exit code", "0"],
                        ["timed out", "false"],
                        ["stderr", "(empty)"],
                        ["stdout (excerpt)", "oracle OK — no anomaly; PEB fields 0"],
                        ["CSV pin_condition_valid", "False (campaign-day IPC/StartServer note)"],
                    ],
                    [2.2 * inch, 5.0 * inch],
                ),
                Paragraph(
                    "TABLE 27. Isolated Pin-without-Pintool probe, 22 Oct 2026, 30 s timeout. Source: pin_probe.csv.",
                    st["Cap"],
                ),
            ]
        )
    )
    stdout_block = (
        "Ocorrências:\n"
        "Resumo de ocorrências:\n"
        "IsDebuggerPresent          : 0\n"
        "CheckRemoteDebuggerPresent : 0\n"
        "ProcessDebugPort           : 0\n"
        "ProcessDebugObjectHandle   : 0\n"
        "PEB.BeingDebugged          : 0\n"
        "PEB.NtGlobalFlag           : 0\n"
        "OK - nenhuma anomalia\n"
        "-------------------------------\n"
        "stderr: (empty)\n"
        "exit_code: 0"
    )
    s.append(Preformatted(stdout_block, st["Pre"]))

    s.append(Paragraph("VI-B Corpus manifesto", st["H"]))
    s.append(
        P(
            st,
            "N",
            "The 100-row manifesto is experiment/corpus/corpus.csv. Columns: SHA-256, source, acquisition date "
            "2026-10-14, class, coarse type, architecture x64, profile, packer/protector, targeted_evasion. "
            "Trojan_Bazaar and Backdoor_Bazaar are coarse MalwareBazaar labels, not VirusTotal families. "
            "Packer/protector remains unknown on the malware rows. targeted_evasion=unverified for all 50 malicious "
            "binaries and none for the 50 benign binaries.",
            True,
        )
    )

    s.append(Paragraph("VI-C — replacement of the Module32 denial", st["H"]))
    s.append(
        P(
            st,
            "N",
            "The five oracles assessed debugging, enumeration, the environment, memory comparisons, and timing. Those "
            "results are not evidence that corpus binaries performed the same checks. ProcessEnum includes a Module32 "
            "positive control on a dummy %TEMP%\\pinvm.dll copy of version.dll (Table 21). Combined activation was "
            "smoke-tested once per oracle (Table 22). InstMemcmpMask family controls cover memcmp, _memicmp, and "
            "RtlCompareMemory; _memicmp_l faulted on the campaign DLL; several comparison exports were not exercised "
            "(Table 23).",
            True,
        )
    )

    s.append(Paragraph("VI-D — 6,517 unavailable exit codes", st["H"]))
    s.append(
        P(
            st,
            "N",
            "Table 19 includes all 9,000 attempts. In the 9,000 JSON records, 6,517 rows were stored as exception_crash "
            "with a null exit_code and exception_code=0x. After Start-Process with redirected streams, Windows "
            "PowerShell 5.1 can leave Process.ExitCode unpopulated; a null compared with < 0 was treated as a crash. "
            "True crashes with a known exit code in those 9,000 records: 0. The original JSON files were not rewritten. "
            "Collector v2.1 (Get-SafeProcessExitCode) applies only to later campaigns. A success rate is not computed "
            "from the 6,517 rows.",
            True,
        )
    )

    s.append(Paragraph("SkewMask diagnostic access_r43 (BEN_28, BEN_46, BEN_47)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "The TMW0 versus TMW_DO corpus contrast uses 2,000 attempts (1,000 per condition), not 9,000. An additional "
            "diagnostic (access_r43_skewmask_diag) selected three persistent benign binaries a priori (campaign TMW0 "
            "n_ok=0, TMW_DO n_ok≥6): BEN_28, BEN_46, BEN_47. Native and TMW0 terminated with −1073741511 "
            "(STATUS_ENTRYPOINT_NOT_FOUND). TMW_DO kept the Pin process tree alive for about 61 s. identified=false. "
            "Persistence is state or wait, not application progress.",
            True,
        )
    )
    s.append(
        KeepTogether(
            [
                make_table(
                    st,
                    ["Sample", "Mode", "Exit", "Elapsed (ms)", "Progress"],
                    [
                        ["BEN_28", "Native", "−1073741511", "1609", "EXITED (peak WS = 0)"],
                        ["BEN_28", "TMW0", "−1073741511", "1687", "EXITED"],
                        ["BEN_28", "TMW_DO", "−1 (timeout)", "61016", "STILL_ALIVE Pin tree"],
                        ["BEN_46", "Native", "−1073741511", "781", "EXITED (peak WS = 0)"],
                        ["BEN_46", "TMW0", "−1073741511", "1938", "EXITED"],
                        ["BEN_46", "TMW_DO", "−1 (timeout)", "61234", "STILL_ALIVE Pin tree"],
                        ["BEN_47", "Native", "−1073741511", "750", "EXITED (peak WS = 0)"],
                        ["BEN_47", "TMW0", "−1073741511", "1703", "EXITED"],
                        ["BEN_47", "TMW_DO", "−1 (timeout)", "61062", "STILL_ALIVE Pin tree"],
                    ],
                    [1.0 * inch, 1.0 * inch, 1.5 * inch, 1.3 * inch, 2.4 * inch],
                ),
                Paragraph(
                    "TABLE 25. SkewMask diagnostic access_r43_skewmask_diag, N=1, 60 s, DLL 4BBC6270. identified=false.",
                    st["Cap"],
                ),
            ]
        )
    )

    s.append(Paragraph("VI-E Resource pairs (already in the English Methods)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "The resource-contrast filter is post hoc and is not in experiment.config.json. Duration: 98 eligible pairs. "
            "CPU and memory: 98 pairs, except SanitizePinEnvVars, which had 97 (BEN_32). MAL_33 and MAL_37 remain in "
            "the 9,000 outcome tables. Intervals are exploratory.",
            True,
        )
    )

    s.append(Paragraph("VII-A — replacement of the Module32 denial", st["H"]))
    s.append(
        P(
            st,
            "N",
            "ProcessEnum hid the pin.exe process entries on the Tool Help path that the process oracle exercised, and hid "
            "the dummy pinvm.dll fixture on the Module32 path (Table 21). The fixture is not the real Pin module. "
            "GetModuleHandleA/W and native NtQuerySystemInformation remain without individual validation.",
            True,
        )
    )

    s.append(Paragraph("Remaining experimental limitations (not marked resolved)", st["H"]))
    s.append(
        P(
            st,
            "N",
            "No new experiments were run for: (1) API traces and code coverage; (2) per-binary hook-invocation counters "
            "(disabled in the 9,000); (3) full temporal coherence; (4) a malware case with identified check, branch, "
            "matching knob, and recovered hashed behavior; (5) experimental comparison with Arancino, COBAI, or Peekaboo.",
            True,
        )
    )
    return s


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
        if line.startswith("|") and set(line.replace("|", "").replace("-", "").replace(" ", "")) == set():
            continue
        if line.startswith("|"):
            cells = [c.strip().replace("`", "") for c in line.strip("|").split("|")]
            story.append(Paragraph(esc(" — ".join(cells)), st["L"]))
            continue
        if line.startswith("- "):
            story.append(Paragraph("• " + esc(line[2:].replace("`", "")), st["L"]))
            continue
        story.append(Paragraph(esc(line.replace("`", "")), st["B"]))
    return story


def write_pdf(out: Path, story):
    doc = SimpleDocTemplate(
        str(out),
        pagesize=letter,
        leftMargin=0.65 * inch,
        rightMargin=0.65 * inch,
        topMargin=0.55 * inch,
        bottomMargin=0.55 * inch,
        title=out.stem,
    )
    doc.build(story)
    print("WROTE", out, out.stat().st_size)


def merge_pdfs(base: Path, addendum: Path, out: Path) -> None:
    try:
        from pypdf import PdfReader, PdfWriter
    except ImportError:
        from PyPDF2 import PdfReader, PdfWriter  # type: ignore
    writer = PdfWriter()
    for src in (base, addendum):
        reader = PdfReader(str(src))
        for page in reader.pages:
            writer.add_page(page)
    with out.open("wb") as f:
        writer.write(f)
    print("MERGED", out, out.stat().st_size, "sha", sha256(out)[:16])


def copy_base() -> Path:
    if not USER_PDF.exists():
        raise FileNotFoundError(USER_PDF)
    digest = sha256(USER_PDF)
    print("BASE_PDF", USER_PDF.name, digest)
    if not digest.startswith(EXPECTED_SHA):
        raise RuntimeError(f"Expected SHA starting {EXPECTED_SHA}, got {digest}")
    dest = HERE / "Access-2026-38745_REVISION_BASE.pdf"
    shutil.copy2(USER_PDF, dest)
    print("COPIED", dest)
    return dest


def main() -> None:
    base = copy_base()
    for hl, suffix, sub in (
        (False, "", "Clean English addendum. Concatenate with the 22-page CFD80 base."),
        (True, "_HL", "HIGHLIGHTED — yellow marks new or replacement sentences. Use \\hl in Overleaf."),
    ):
        st = styles(hl)
        add_path = OUT / f"Access-2026-38745_Revision_Addendum{suffix}.pdf"
        write_pdf(add_path, addendum_story(st))
        merged = OUT / f"Access-2026-38745_REVISION{suffix}.pdf"
        merge_pdfs(base, add_path, merged)
        letter_path = OUT / f"Access-2026-38745_Response_to_Reviewers{suffix}.pdf"
        write_pdf(
            letter_path,
            flow_from_md(
                HERE / "CARTA_FINAL_EN.md",
                st,
                "Response to Reviewers — Access-2026-38745",
                sub if not hl else "HIGHLIGHTED draft of the point-by-point letter.",
            ),
        )


if __name__ == "__main__":
    main()
