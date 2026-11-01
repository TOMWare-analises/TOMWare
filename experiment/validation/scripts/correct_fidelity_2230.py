# -*- coding: utf-8 -*-
"""22/30 correction: 0-byte stdout keeps an empty hash field (not SHA-256 of '')."""
from __future__ import annotations

import csv
import hashlib
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias\TOMWare")
SRC = ROOT / "experiment" / "results" / "oracles" / "fidelity_by_run.csv"
OUT = ROOT / "experiment" / "results" / "oracles" / "fidelity_pairs_2230.csv"
NOTE = ROOT / "experiment" / "validation" / "manuscript" / "ieee_access_ressubmissao" / "CORRECAO_22_30.md"
EMPTY_BUF = hashlib.sha256(b"").hexdigest()


def kind(sha: str, nbytes: int) -> str:
    if nbytes == 0:
        return "empty_field"
    if (sha or "").lower() == EMPTY_BUF:
        return "empty_buffer_sha_unexpected"
    return "sha256"


def main() -> None:
    rows = list(csv.DictReader(SRC.open(encoding="utf-8-sig", newline="")))
    pairs = []
    n_agree = n_diff = n_empty_agree = n_hash_agree = 0
    n_empty_buf = 0
    for r in rows:
        sha = (r.get("stdout_sha256") or "").strip()
        nbytes = int(r.get("stdout_bytes") or 0)
        if sha.lower() == EMPTY_BUF:
            n_empty_buf += 1
        if nbytes == 0 and sha:
            raise SystemExit(f"raw CSV still hashed a 0-byte stdout: {r['run_id']} {sha}")

    ids = sorted({r["sample_id"] for r in rows})
    for sid in ids:
        for att in ("1", "2", "3"):
            a = next(r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "TMW0")
            b = next(r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "TMW_ALL")
            sa, sb = (a.get("stdout_sha256") or "").strip(), (b.get("stdout_sha256") or "").strip()
            ba, bb = int(a.get("stdout_bytes") or 0), int(b.get("stdout_bytes") or 0)
            ka, kb = kind(sa, ba), kind(sb, bb)
            exit_eq = a["exit_code"] == b["exit_code"]
            hash_eq = sa == sb
            agree = exit_eq and hash_eq
            empty_agree = agree and ba == 0 and bb == 0
            if agree:
                n_agree += 1
                if empty_agree:
                    n_empty_agree += 1
                else:
                    n_hash_agree += 1
            else:
                n_diff += 1
            pairs.append({
                "sample_id": sid,
                "attempt": att,
                "tmw0_exit": a["exit_code"],
                "tmw_all_exit": b["exit_code"],
                "tmw0_stdout_bytes": ba,
                "tmw_all_stdout_bytes": bb,
                "tmw0_stdout_sha256": sa,
                "tmw_all_stdout_sha256": sb,
                "tmw0_hash_kind": ka,
                "tmw_all_hash_kind": kb,
                "exit_equal": exit_eq,
                "stdout_field_equal": hash_eq,
                "pair_agrees": agree,
                "empty_stdout_both": ba == 0 and bb == 0,
                "empty_field_agreement": empty_agree,
                "used_empty_buffer_sha": EMPTY_BUF,
                "note": (
                    "0-byte stdout: hash field left empty; not SHA-256 of the empty buffer"
                    if ba == 0 or bb == 0 else
                    "non-empty stdout compared by SHA-256"
                ),
            })

    fields = list(pairs[0].keys())
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(pairs)

    diffs = [p for p in pairs if not p["pair_agrees"]]
    lines = [
        "# 22/30 diagnostic correction (Access)",
        "",
        "Source: `experiment/results/oracles/fidelity_by_run.csv` (collector `Run-Fidelity.ps1`).",
        "Derived: `experiment/results/oracles/fidelity_pairs_2230.csv`.",
        "",
        "The collector already leaves `stdout_sha256` **empty** when `stdout_bytes=0`",
        f"(it does not write `{EMPTY_BUF}`, the SHA-256 of a zero-length buffer).",
        "The earlier insert that said “an empty stdout is hashed as the empty buffer” is withdrawn.",
        "",
        "Agreement criterion (unchanged numerically): equal exit code **and** equal stdout hash field.",
        "Two empty fields are equal fields, not equal hashes of empty buffers.",
        "",
        f"| Result | n |",
        f"|---|---|",
        f"| TMW0 vs TMW_ALL pairs | {n_agree + n_diff} |",
        f"| Agree | {n_agree} |",
        f"| Disagree | {n_diff} |",
        f"| Of the agrees: both stdout 0 bytes (empty hash field) | {n_empty_agree} |",
        f"| Of the agrees: non-empty stdout SHA-256 | {n_hash_agree} |",
        f"| Raw rows that stored SHA-256 of empty buffer | {n_empty_buf} |",
        "",
        "Disagreements (exit differs; stdout field may still match):",
        "",
        "| Sample | Rep | TMW0 exit | TMW_ALL exit | stdout bytes |",
        "|---|---|---|---|---|",
    ]
    for p in diffs:
        lines.append(
            f"| {p['sample_id']} | {p['attempt']} | {p['tmw0_exit']} | {p['tmw_all_exit']} | "
            f"{p['tmw0_stdout_bytes']}→{p['tmw_all_stdout_bytes']} |"
        )
    lines += [
        "",
        "Do not call 22/30 behavioral fidelity. Empty-field agreement is an external observable only.",
        "",
    ]
    NOTE.write_text("\n".join(lines), encoding="utf-8")
    print("PAIRS", n_agree, "DIFF", n_diff, "EMPTY_AGREE", n_empty_agree, "HASH_AGREE", n_hash_agree)
    print("OUT", OUT)
    print("NOTE", NOTE)


if __name__ == "__main__":
    main()
