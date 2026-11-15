// Monta o texto do roteiro (título, etiqueta e notas de cada slide) a partir de slides/project.
// Uso (raiz do repo):  node tools/roteiro.mjs <saida.json>   -> {text, styles: [[inicio, fim, estilo]]}
import { readFileSync, writeFileSync } from "node:fs";
const D = "slides/project/";
const deck = JSON.parse(readFileSync(D + "deck.json", "utf8"));
const order = deck.order;
const sectionAt = Object.fromEntries(Object.values(deck.sections).map((s) => [s.start, s.description]));
const plain = (s) => s.replace(/<[^>]+>/g, " ").replace(/&#160;/g, " ").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
const tag = (re, s) => { const m = s.match(re); return m ? plain(m[1]) : ""; };
const P = [
  ["Roteiro da apresentação: Istio na prática (GB)", "TITLE"],
  ["O que falar em cada slide, na ordem do enunciado. Os slides mostram o resumo e este roteiro traz a explicação. Tempo-alvo: cerca de 15 minutos; o apêndice é só para perguntas.", "NORMAL_TEXT"],
];
order.forEach((id, i) => {
  const s = readFileSync(D + `slides/${id}.html`, "utf8");
  if (sectionAt[id]) P.push([id === "apendice" ? "Apêndice (usar só se perguntarem)" : sectionAt[id], "HEADING_1"]);
  const title = tag(/<h1[^>]*>([\s\S]*?)<\/h1>/, s) || tag(/<h2[^>]*>([\s\S]*?)<\/h2>/, s);
  P.push([`Slide ${i + 1}: ${title}`, "HEADING_2"]);
  P.push([tag(/<aside[^>]*>([\s\S]*?)<\/aside>/, s), "NORMAL_TEXT"]);
});
let text = "", idx = 1;
const styles = [];
for (const [t, st] of P) { console.assert(t, "parágrafo vazio"); styles.push([idx, idx + t.length + 1, st]); text += t + "\n"; idx += t.length + 1; }
writeFileSync(process.argv[2], JSON.stringify({ text, styles }));
console.log(P.length, "parágrafos,", text.length, "caracteres");
