import csv
from collections import defaultdict, Counter
from pathlib import Path

p = Path(__file__).resolve().parents[2] / "results" / "oracles" / "counters" / "module_events_by_run.csv"
rows = list(csv.DictReader(p.open(encoding="utf-8-sig", newline="")))

def i(r, k):
    try:
        return int(float(str(r.get(k, 0) or 0).strip() or 0))
    except Exception:
        return 0

print("rows", len(rows))
print("unique run_id", len({r["run_id"] for r in rows}))
print("json_ok", sum(1 for r in rows if i(r, "counters_json_ok") == 1))

by_grp = defaultdict(list)
by_arm = defaultdict(list)
by_sid = defaultdict(list)
for r in rows:
    by_grp[r["group"]].append(r)
    by_arm[r["arm"]].append(r)
    by_sid[r["sample_id"]].append(r)

print("\n=== by group ===")
for g, rs in sorted(by_grp.items()):
    n = len(rs)
    jok = sum(1 for r in rs if i(r, "counters_json_ok") == 1)
    surf = sum(1 for r in rs if i(r, "surface_observed") == 1)
    trig = sum(1 for r in rs if i(r, "countermeasure_triggered") == 1)
    mod = sum(1 for r in rs if i(r, "result_modified") == 1)
    print(f"{g:10} n={n} json={jok} surf={surf} trig={trig} mod={mod}")

print("\n=== by arm ===")
for a, rs in sorted(by_arm.items()):
    n = len(rs)
    jok = sum(1 for r in rs if i(r, "counters_json_ok") == 1)
    print(f"{a:16} n={n} json={jok}")

print("\n=== module flags (json_ok only) ===")
mods = [
    ("ad", "ad_surface", "ad_triggered", "ad_modified"),
    ("pe", "pe_surface", "pe_triggered", "pe_modified"),
    ("env", "env_surface", "env_triggered", "env_modified"),
    ("mc", "mc_surface", "mc_triggered", "mc_modified"),
    ("sk", "sk_surface", "sk_triggered", "sk_modified"),
]
ok = [r for r in rows if i(r, "counters_json_ok") == 1]
for name, s, t, m in mods:
    for label, subset in (("ALL", ok), ("BEN", [r for r in ok if r["group"] == "benign"]), ("MAL", [r for r in ok if r["group"] == "malicious"])):
        ns = len(subset)
        if ns == 0:
            continue
        print(f"  {label:3} {name} surf={sum(i(r,s) for r in subset):4}/{ns} trig={sum(i(r,t) for r in subset):4} mod={sum(i(r,m) for r in subset):4}")

print("\n=== per sample json / surf / trig ===")
ids = [f"BEN_{n:02d}" for n in range(1, 16)] + [f"MAL_{n:02d}" for n in range(1, 16)]
for sid in ids:
    rs = by_sid.get(sid, [])
    jok = sum(1 for r in rs if i(r, "counters_json_ok") == 1)
    surf = sum(1 for r in rs if i(r, "surface_observed") == 1)
    trig = sum(1 for r in rs if i(r, "countermeasure_triggered") == 1)
    exits = Counter(r.get("exit_code") for r in rs)
    print(f"{sid} n={len(rs):2} json={jok:2} surf={surf:2} trig={trig:2} exits={dict(exits)}")

print("\n=== TMW0 vs TMW_ALL among json_ok ===")
for arm in ("TMW0_COUNT", "TMW_ALL_COUNT"):
    rs = [r for r in ok if r["arm"] == arm]
    print(f"{arm} n={len(rs)}")
    for name, s, t, m in mods:
        print(f"    {name} surf={sum(i(r,s) for r in rs)} trig={sum(i(r,t) for r in rs)} mod={sum(i(r,m) for r in rs)}")

print("\n=== numeric sums json_ok ===")
keys = ["pe_calls", "pe_filtered", "env_found", "env_sanitized", "mc_intercepted", "mc_matched", "sk_sleep", "sk_corrections", "ad_sanitizations"]
for g in ("benign", "malicious"):
    rs = [r for r in ok if r["group"] == g]
    print(g, {k: sum(i(r, k) for r in rs) for k in keys})

print("\n=== last 15 run_ids ===")
for r in rows[-15:]:
    print(r["run_id"], "json", r["counters_json_ok"], "surf", r["surface_observed"], "exit", r["exit_code"])
