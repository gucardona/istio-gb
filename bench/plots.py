"""Gera paper/figs/*.pdf e paper/tabelas.tex a partir de results/. Uso: python3 bench/plots.py"""
import json, glob, re, statistics as st, os
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
R, P = "results", "paper"; os.makedirs(f"{P}/figs", exist_ok=True)

def load(f):
    d = json.load(open(f)); p = {x["Percentile"]: x["Value"] * 1e3 for x in d["DurationHistogram"]["Percentiles"]}
    c = d["RetCodes"]; tot = sum(c.values())
    return dict(qps=d["ActualQPS"], p50=p[50], p90=p[90], p99=p[99], avg=d["DurationHistogram"]["Avg"] * 1e3,
                ok=c.get("200", 0), tot=tot, err=100 * (1 - c.get("200", 0) / tot), codes=c)
def agg(files, k):
    v = [load(f)[k] for f in files]; return st.mean(v), (st.stdev(v) if len(v) > 1 else 0)

tex = []
# ---- S0: custo da malha
rows = []; fig, ax = plt.subplots(1, 2, figsize=(7, 2.8))
for i, q in enumerate([50, 500]):
    for j, ns in enumerate(["plain", "mesh"]):
        fs = sorted(glob.glob(f"{R}/s0/{ns}_q{q}_r*.json"))
        if not fs: continue
        m50, s50 = agg(fs, "p50"); m99, s99 = agg(fs, "p99"); mq, _ = agg(fs, "qps")
        rows.append((q, ns, mq, m50, s50, m99, s99))
        ax[i].bar([j - .2, j + .2], [m50, m99], .4, yerr=[s50, s99], color=["#4c78a8", "#e45756"], capsize=2)
    ax[i].set_xticks([0, 1]); ax[i].set_xticklabels(["sem malha", "com Istio"]); ax[i].set_title(f"{q} req/s"); ax[i].set_ylabel("ms")
ax[0].legend(handles=[plt.Rectangle((0, 0), 1, 1, color="#4c78a8"), plt.Rectangle((0, 0), 1, 1, color="#e45756")], labels=["p50", "p99"], fontsize=7)
plt.tight_layout(); plt.savefig(f"{P}/figs/s0_overhead.pdf"); plt.close()
tex += [r"% S0", r"\begin{tabular}{rlrrrrr}\hline", r"req/s & Modo & Vaz\~ao & p50 (ms) & $\sigma$ & p99 (ms) & $\sigma$ \\ \hline"]
for q, ns, mq, a, sa, b, sb in rows:
    tex.append(rf"{q} & {'Istio' if ns == 'mesh' else 'Sem malha'} & {mq:.0f} & {a:.1f} & {sa:.1f} & {b:.1f} & {sb:.1f} \\")
tex += [r"\hline\end{tabular}", ""]

# ---- S1: canário
cfg = [(100, 0), (90, 10), (50, 50), (0, 100)]; fig, ax = plt.subplots(figsize=(4.2, 2.8)); obs = []
for i, (a, b) in enumerate(cfg):
    t = open(f"{R}/s1/split_{a}_{b}.txt").read(); n = {v: int(c) for c, v in re.findall(r"(\d+)\s+(v\d)", t)}
    tot = sum(n.values()); p2 = 100 * n.get("v2", 0) / tot; obs.append((a, b, 100 - p2, p2, tot))
    ax.bar(i, 100 - p2, color="#4c78a8", label="v1" if i == 0 else None); ax.bar(i, p2, bottom=100 - p2, color="#f58518", label="v2" if i == 0 else None)
ax.set_xticks(range(4)); ax.set_xticklabels([f"{a}/{b}" for a, b in cfg]); ax.set_xlabel("peso configurado v1/v2 (%)"); ax.set_ylabel("% observado"); ax.legend(fontsize=7)
plt.tight_layout(); plt.savefig(f"{P}/figs/s1_canario.pdf"); plt.close()
tex += [r"% S1", r"\begin{tabular}{rrrr}\hline", r"v1/v2 config. & v1 obs. (\%) & v2 obs. (\%) & n \\ \hline"]
for a, b, p1, p2, n in obs: tex.append(rf"{a}/{b} & {p1:.1f} & {p2:.1f} & {n} \\")
tex += [r"\hline\end{tabular}", ""]

# ---- S2: resiliência
names = [("1_baseline", "Sem falha"), ("2_fault", r"Falha (50\% +2 s)"), ("3_fault_timeout", "Falha + timeout/retry")]
fig, ax = plt.subplots(1, 2, figsize=(7, 2.8)); tex += [r"% S2", r"\begin{tabular}{lrrrr}\hline", r"Configura\c{c}\~ao & p50 (ms) & p99 (ms) & Erros (\%) & Vaz\~ao \\ \hline"]
for i, (f, lab) in enumerate(names):
    x = load(f"{R}/s2/{f}.json"); ax[0].bar([i - .2, i + .2], [x["p50"], x["p99"]], .4, color=["#4c78a8", "#e45756"]); ax[1].bar(i, x["err"], color="#54a24b")
    tex.append(rf"{lab} & {x['p50']:.0f} & {x['p99']:.0f} & {x['err']:.1f} & {x['qps']:.0f} \\")
tex += [r"\hline\end{tabular}", ""]
for a in ax: a.set_xticks(range(3)); a.set_xticklabels(["sem falha", "falha", "falha+\ntimeout"], fontsize=7)
ax[0].set_ylabel("ms (azul p50, vermelho p99)"); ax[1].set_ylabel("erros (%)"); plt.tight_layout(); plt.savefig(f"{P}/figs/s2_resiliencia.pdf"); plt.close()
cb = {k: load(f"{R}/s2/{f}.json") for k, f in [("off", "4_cb_off"), ("on", "5_cb_on")]}
fig, ax = plt.subplots(figsize=(3.4, 2.8))
for i, k in enumerate(["off", "on"]): ax.bar(i, cb[k]["ok"], color="#4c78a8", label="200" if i == 0 else None); ax.bar(i, cb[k]["tot"] - cb[k]["ok"], bottom=cb[k]["ok"], color="#e45756", label="503" if i == 0 else None)
ax.set_xticks([0, 1]); ax.set_xticklabels(["sem CB", "com CB"]); ax.set_ylabel("requisições em 10 s"); ax.legend(fontsize=7); plt.tight_layout(); plt.savefig(f"{P}/figs/s2_cb.pdf"); plt.close()
tex += [r"% CB", r"\begin{tabular}{lrrrr}\hline", r" & Total & 200 & 503 & p50 (ms) \\ \hline"]
for k, lab in [("off", "Sem circuit breaker"), ("on", "Com circuit breaker")]:
    x = cb[k]; tex.append(rf"{lab} & {x['tot']} & {x['ok']} & {x['tot'] - x['ok']} & {x['p50']:.1f} \\")
tex += [r"\hline\end{tabular}", ""]

# ---- CPU/RAM dos sidecars (S0, carga de 500 req/s)
def top(f):
    out = {}
    for l in open(f).read().splitlines()[1:]:
        pod, c, cpu, mem = l.split()[:4]; out.setdefault(c, []).append((int(cpu.rstrip("m")), int(mem.rstrip("Mi"))))
    return out
for ns in ["plain", "mesh"]:
    fs = sorted(glob.glob(f"{R}/s0/top_{ns}_q500_r*.txt"))
    if fs:
        t = [top(f) for f in fs]; cpu = {c: st.mean(sum(x[0] for x in d.get(c, [])) for d in t) for c in {"app", "istio-proxy"}}
        mem = {c: st.mean(sum(x[1] for x in d.get(c, [])) for d in t) for c in {"app", "istio-proxy"}}
        tex.append(f"% TOP {ns} (m cores / MiB, soma dos pods, media das reps): app cpu={cpu['app']:.0f} mem={mem['app']:.0f}; sidecar cpu={cpu['istio-proxy']:.0f} mem={mem['istio-proxy']:.0f}")
open(f"{P}/tabelas.tex", "w").write("\n".join(tex)); print("\n".join(tex))
