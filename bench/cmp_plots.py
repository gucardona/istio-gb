#!/usr/bin/env python3
"""Gráficos do comparativo A/B/C a partir de results/cmp/summary.json (rode antes bench/cmp_summary.py).
Gera evidencias/15-cmp-latencia.png, 16-cmp-resiliencia.png e paper/figs/cmp_latencia.pdf, cmp_resiliencia.pdf."""
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

S = json.loads(Path("results/cmp/summary.json").read_text())
M = [("plain", "A: HTTP puro", "#9aa5b1"), ("applib", "B: mTLS/resiliência no código", "#3b82c4"), ("mesh", "C: Istio", "#e07a1f")]
Path("paper/figs").mkdir(parents=True, exist_ok=True)


def save(fig, name, pdf):
    fig.tight_layout()
    fig.savefig(f"evidencias/{name}.png", dpi=150)
    fig.savefig(f"paper/figs/{pdf}.pdf")


# latência p50 e p99 por cenário (q, c)
cases = [(50, 1), (500, 1), (50, 32), (500, 32)]
fig, axs = plt.subplots(1, 2, figsize=(11, 4))
for ax, pct in zip(axs, ("p50", "p99")):
    w = 0.27
    for i, (m, lab, col) in enumerate(M):
        ys = [S["lat"][f"{m}_q{q}_c{c}"][pct] for q, c in cases]
        bars = ax.bar([x + (i - 1) * w for x in range(len(cases))], ys, w, label=lab, color=col)
        ax.bar_label(bars, fmt="%.1f", fontsize=7)
    ax.set_xticks(range(len(cases)), [f"{q} req/s\n{c} " + ("conexões" if c > 1 else "conexão") for q, c in cases])
    ax.set_ylabel(f"latência {pct} (ms)")
    ax.set_title(f"Latência {pct} fim a fim (3 saltos, mediana de 3 rodadas)", fontsize=10)
    ax.spines[["top", "right"]].set_visible(False)
axs[0].legend(frameon=False, fontsize=8)
save(fig, "15-cmp-latencia", "cmp_latencia")

# resiliência: % de requisições que levaram > 1 s (cauda) e p99, por fase
R = S["res"]
phases = [("1_base", "sem falha"), ("2_fault", "falha 2 s em 50%"), ("3_fault_policy", "falha + timeout/retry")]
fig, ax = plt.subplots(figsize=(8, 4))
w = 0.27
for i, (m, lab, col) in enumerate(M):
    ys = [R.get(f"{m}_{p}", {}).get("p99", 0) for p, _ in phases]
    bars = ax.bar([x + (i - 1) * w for x in range(len(phases))], ys, w, label=lab, color=col)
    ax.bar_label(bars, labels=[f"{y:.0f}" if y else "n/a" for y in ys], fontsize=7)
ax.set_xticks(range(len(phases)), [p for _, p in phases])
ax.set_ylabel("latência p99 (ms)")
ax.set_title("Resiliência: p99 com inventory lento (A não tem a função)", fontsize=10)
ax.spines[["top", "right"]].set_visible(False)
ax.legend(frameon=False, fontsize=8)
save(fig, "16-cmp-resiliencia", "cmp_resiliencia")
print("ok")
