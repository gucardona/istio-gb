#!/usr/bin/env bash
# Roda o comparativo mostrando a saída ao vivo e guardando em results/cmp.log
cd "$(dirname "$0")/.." && mkdir -p results/cmp
./bench/compare.sh sec res lat 2>&1 | tee results/cmp.log
echo "FIM DO COMPARATIVO" | tee -a results/cmp.log
