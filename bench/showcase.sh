#!/usr/bin/env bash
# Mesma carga (300 req/s, 16 conexões, 2 min) em A, B e C, um após o outro, para os gráficos de CPU/RAM por namespace.
# Uso (raiz do repo, no WSL):  ./bench/showcase.sh
set -uo pipefail
TLSF="-cacert /tls/ca.crt -cert /tls/tls.crt -key /tls/tls.key"
for m in plain applib mesh; do
  echo ">> $m $(date +%T)"
  if [ "$m" = applib ]; then kubectl -n applib exec deploy/load -c fortio -- fortio load -quiet $TLSF -qps 300 -c 16 -t 120s https://frontend:8080/ 2>&1 | grep -E "Code|All done"
  else kubectl -n "$m" exec deploy/load -c fortio -- fortio load -quiet -qps 300 -c 16 -t 120s http://frontend:8080/ 2>&1 | grep -E "Code|All done"; fi
  sleep 20
done
echo "FIM $(date +%T)"
