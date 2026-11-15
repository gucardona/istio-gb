#!/usr/bin/env python3
"""Gera slides/roteiro.html (título + o que falar em cada slide) a partir das notas <aside> do deck.
Uso (raiz do repo):  python3 tools/roteiro.py   -> sobe para o Drive como Google Doc."""
import json, re, html
from pathlib import Path

D = Path("slides/project")
order = json.loads((D / "deck.json").read_text())["order"]
tag = lambda t, s: (m.group(1) if (m := re.search(rf"<{t}[^>]*>(.*?)</{t}>", s, re.S)) else "")
plain = lambda s: html.unescape(re.sub(r"<[^>]+>", " ", s)).split() and " ".join(html.unescape(re.sub(r"<[^>]+>", " ", s)).split())

out = ["<html><head><meta charset='utf-8'></head><body>",
       "<h1>Roteiro da apresentação – Istio na prática (GB)</h1>",
       "<p>O que falar em cada slide. Os slides têm pouco texto; a explicação está aqui. "
       "Tempo-alvo: cerca de 15 minutos (o apêndice é só para perguntas).</p>"]
for i, sid in enumerate(order, 1):
    s = (D / f"slides/{sid}.html").read_text()
    if sid == "apendice":
        out.append("<h2>Apêndice – usar só se perguntarem</h2>")
    title = plain(tag("h1", s) or tag("h2", s))
    out.append(f"<h3>Slide {i} – {html.escape(title)}</h3>")
    out.append(f"<p>{html.escape(plain(tag('aside', s)))}</p>")
out.append("</body></html>")
Path("slides/roteiro.html").write_text("\n".join(out))
print(len(order), "slides")
