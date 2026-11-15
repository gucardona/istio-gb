#!/usr/bin/env python3
"""Resumo do comparativo A/B/C (results/cmp): latência por q/c (mediana das 3 rodadas), CPU/RAM e resiliência.
Uso (raiz do repo):  python3 bench/cmp_summary.py   -> imprime e grava results/cmp/summary.json"""
import json, glob, re, statistics as st
from pathlib import Path

D = Path("results/cmp")
MODES = ["plain", "applib", "mesh"]
CHAIN = ("frontend", "catalog", "inventory")  # só os serviços da cadeia, sem o gerador de carga


def fortio(f):
    j = json.loads(Path(f).read_text())
    h = j["DurationHistogram"]
    pc = {p["Percentile"]: p["Value"] * 1000 for p in h["Percentiles"]}
    codes = {str(k): v for k, v in j["RetCodes"].items()}
    return dict(qps=j["ActualQPS"], avg=h["Avg"] * 1000, p50=pc[50], p90=pc[90], p99=pc[99], codes=codes, n=h["Count"])


def top(f):
    cpu = mem = 0
    for line in Path(f).read_text().splitlines()[1:]:
        c = line.split()
        if len(c) >= 4 and c[0].startswith(CHAIN):
            cpu += int(re.sub(r"\D", "", c[2]) or 0)
            mem += int(re.sub(r"\D", "", c[3]) or 0)
    return cpu, mem


out = {"lat": {}, "res": {}}
print(f"{'modo':7} {'q':>4} {'c':>3} | {'qps':>6} {'média':>7} {'p50':>7} {'p90':>7} {'p99':>7} | {'CPU m':>6} {'RAM Mi':>6}")
for q in (50, 500):
    for c in (1, 32):
        for m in MODES:
            runs = [fortio(f) for f in sorted(glob.glob(str(D / f"lat/{m}_q{q}_c{c}_r*.json")))]
            tops = [top(f) for f in sorted(glob.glob(str(D / f"lat/{m}_q{q}_c{c}_r*.top.txt")))]
            r = {k: st.median(x[k] for x in runs) for k in ("qps", "avg", "p50", "p90", "p99")}
            r["cpu"] = st.median(t[0] for t in tops) if tops else None
            r["mem"] = st.median(t[1] for t in tops) if tops else None
            r["reps"] = len(runs)
            out["lat"][f"{m}_q{q}_c{c}"] = r
            print(f"{m:7} {q:>4} {c:>3} | {r['qps']:6.1f} {r['avg']:7.2f} {r['p50']:7.2f} {r['p90']:7.2f} {r['p99']:7.2f} | {r['cpu']:>6} {r['mem']:>6}")

print("\nresiliência (falha de 2 s em 50% das chamadas ao inventory; CB com 20 conexões)")
for f in sorted(glob.glob(str(D / "res/*.json"))):
    k = Path(f).stem
    r = fortio(f)
    out["res"][k] = r
    print(f"{k:24} qps={r['qps']:6.1f} média={r['avg']:8.1f} p50={r['p50']:7.1f} p99={r['p99']:7.1f}  {r['codes']}")

(D / "summary.json").write_text(json.dumps(out, indent=1))
