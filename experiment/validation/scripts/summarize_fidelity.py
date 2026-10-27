import csv
from collections import defaultdict, Counter
from pathlib import Path

p = Path(__file__).resolve().parents[2] / "results" / "oracles" / "fidelity_by_run.csv"
rows = list(csv.DictReader(p.open(encoding="utf-8-sig", newline="")))

def i(r, k):
    try:
        return int(float(str(r.get(k, 0) or 0).strip() or 0))
    except Exception:
        return 0

print("rows", len(rows), "unique", len({r["run_id"] for r in rows}))
print("arms", Counter(r["arm"] for r in rows))
print("samples", sorted(set(r["sample_id"] for r in rows)))

print("\n=== per sample x arm: exits / stdout_sha / kids / files ===")
ids = sorted(set(r["sample_id"] for r in rows))
arms = ["NAT", "EMPTY", "TMW0", "TMW_ALL"]
for sid in ids:
    print(f"\n{sid}")
    for arm in arms:
        rs = [r for r in rows if r["sample_id"] == sid and r["arm"] == arm]
        exits = Counter(r.get("exit_code") for r in rs)
        shas = Counter(r.get("stdout_sha256") or "" for r in rs)
        outb = [i(r, "stdout_bytes") for r in rs]
        kids = [i(r, "child_proc_count") for r in rs]
        files = [i(r, "new_files_count") for r in rs]
        durs = [i(r, "duration_ms") for r in rs]
        print(f"  {arm:8} n={len(rs)} exit={dict(exits)} out_sha={len(shas)} uniq out_bytes={outb} kids={kids} files={files} dur={durs}")

print("\n=== TMW0 vs TMW_ALL stdout hash match (same sample, same attempt) ===")
match = miss = 0
for sid in ids:
    for att in set(r["attempt"] for r in rows if r["sample_id"] == sid):
        a = [r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "TMW0"]
        b = [r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "TMW_ALL"]
        if not a or not b:
            continue
        sa, sb = a[0].get("stdout_sha256") or "", b[0].get("stdout_sha256") or ""
        ea, eb = a[0].get("exit_code"), b[0].get("exit_code")
        if sa == sb and ea == eb:
            match += 1
        else:
            miss += 1
            print(f"  DIFF {sid} att={att} exit {ea}->{eb} out {sa[:8]}->{sb[:8]} bytes {a[0].get('stdout_bytes')}->{b[0].get('stdout_bytes')}")
print("TMW0==TMW_ALL pairs", match, "diff", miss)

print("\n=== NAT vs TMW0 stdout/exit ===")
match = miss = 0
for sid in ids:
    for att in set(r["attempt"] for r in rows if r["sample_id"] == sid):
        a = [r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "NAT"]
        b = [r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "TMW0"]
        if not a or not b:
            continue
        sa, sb = a[0].get("stdout_sha256") or "", b[0].get("stdout_sha256") or ""
        ea, eb = a[0].get("exit_code"), b[0].get("exit_code")
        if sa == sb and ea == eb:
            match += 1
        else:
            miss += 1
print("NAT==TMW0 pairs", match, "diff", miss)

print("\n=== EMPTY vs TMW0 ===")
match = miss = 0
for sid in ids:
    for att in set(r["attempt"] for r in rows if r["sample_id"] == sid):
        a = [r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "EMPTY"]
        b = [r for r in rows if r["sample_id"] == sid and r["attempt"] == att and r["arm"] == "TMW0"]
        if not a or not b:
            continue
        sa, sb = a[0].get("stdout_sha256") or "", b[0].get("stdout_sha256") or ""
        ea, eb = a[0].get("exit_code"), b[0].get("exit_code")
        if sa == sb and ea == eb:
            match += 1
        else:
            miss += 1
print("EMPTY==TMW0 pairs", match, "diff", miss)

print("\n=== kids/files any non-zero ===")
print("kids>0", sum(1 for r in rows if i(r, "child_proc_count") > 0))
print("files>0", sum(1 for r in rows if i(r, "new_files_count") > 0))
print("timed_out", sum(1 for r in rows if str(r.get("timed_out")).lower() == "true"))
print("exit counters", Counter(r.get("exit_code") for r in rows))
