#!/usr/bin/env bash
# Abre os painéis de observabilidade em localhost (Ctrl-C encerra todos).
# kiali :20001  grafana :3000  jaeger :16686  prometheus :9090  loki :3100
trap 'kill 0' EXIT
f() { kubectl -n istio-system port-forward "svc/$1" "$2:$3" >/dev/null 2>&1 & }
f kiali 20001 20001
f grafana 3000 3000
f tracing 16686 80
f prometheus 9090 9090
f loki 3100 3100
echo "kiali http://localhost:20001/kiali | grafana http://localhost:3000 | jaeger http://localhost:16686 | prometheus http://localhost:9090 | loki http://localhost:3100"
wait
