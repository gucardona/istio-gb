#!/usr/bin/env bash
# Diagnóstico da latência: (a) varia conexões a 50 req/s; (b) varia saltos (inventory=1, catalog=2, frontend=3).
set -uo pipefail
OUT=${OUT:-results/diag}; mkdir -p "$OUT"; D=${DUR:-20s}
run() { kubectl -n "$1" exec deploy/load -c fortio -- fortio load -quiet -json - -allow-initial-errors -qps "$2" -c "$3" -t "$D" "http://$4:8080/" > "$OUT/$1_$4_q$2_c$3.json"; }
for ns in plain mesh; do
  for c in 1 4 8 32 64; do echo ">> $ns frontend c=$c"; run $ns 50 $c frontend; sleep 3; done
  for svc in inventory catalog; do for c in 8 32; do echo ">> $ns $svc c=$c"; run $ns 50 $c $svc; sleep 3; done; done
done
