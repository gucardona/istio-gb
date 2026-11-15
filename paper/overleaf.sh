#!/usr/bin/env bash
# Monta paper/overleaf.zip (tudo num diretório só, sem ../) e recompila paper/main.pdf.
# Uso (raiz do repo, no WSL):  ./paper/overleaf.sh
set -euo pipefail
cd "$(dirname "$0")"
rm -rf overleaf overleaf.zip
mkdir -p overleaf/figs
cp main.tex refs.bib sbc-template.sty sbc.bst overleaf/
cp figs/cmp_latencia.pdf figs/cmp_resiliencia.pdf overleaf/figs/
cp ../evidencias/01-kiali-seguranca.png ../evidencias/14-jaeger-trace.png overleaf/figs/
sed -i 's|\\graphicspath{{figs/}{../evidencias/}}|\\graphicspath{{figs/}}|' overleaf/main.tex
grep -n graphicspath overleaf/main.tex
(cd overleaf && tectonic -X compile main.tex 2>&1 | grep -iE "error|overfull|undefined" || echo "overleaf: compilou sem erros"; rm -f main.pdf)
(cd overleaf && python3 -m zipfile -c ../overleaf.zip main.tex refs.bib sbc-template.sty sbc.bst figs)
python3 -m zipfile -l overleaf.zip
tectonic -X compile main.tex 2>&1 | grep -iE "error|overfull|undefined" || echo "main.pdf: compilou sem erros"
