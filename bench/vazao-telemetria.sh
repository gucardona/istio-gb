#!/usr/bin/env bash
# Vazão máxima do caso C (mesh) com a telemetria das evidências (tracing 100% + access log)
# e com a telemetria próxima do padrão (tracing 1%, sem access log). Restaura tudo no fim.
# Uso (raiz do repo, no WSL):  ./bench/vazao-telemetria.sh
set -uo pipefail
OUT=results/vazao; REPS=${REPS:-3}; mkdir -p "$OUT"
run() { # run <rótulo>
  for r in $(seq "$REPS"); do
    echo ">> $1 rep=$r"
    kubectl -n mesh exec deploy/load -c fortio -- fortio load -quiet -json - -qps 0 -c 20 -t 20s http://frontend:8080/ > "$OUT/${1}_r$r.json" &
    p=$!; sleep 12
    kubectl top node > "$OUT/${1}_r$r.node.txt" 2>/dev/null
    kubectl top pods --containers -n mesh > "$OUT/${1}_r$r.pods.txt" 2>/dev/null
    wait $p; sleep 5
  done
}
restore() {
  kubectl -n istio-system patch telemetry tracing-100 --type merge \
    -p '{"spec":{"tracing":[{"providers":[{"name":"zipkin"}],"randomSamplingPercentage":100}]}}' >/dev/null
  kubectl apply -f k8s/accesslog.yaml >/dev/null
}
trap restore EXIT

run evid   # como nas evidências
kubectl -n istio-system patch telemetry tracing-100 --type merge \
  -p '{"spec":{"tracing":[{"providers":[{"name":"zipkin"}],"randomSamplingPercentage":1}]}}' >/dev/null
kubectl -n mesh delete telemetry access-log --ignore-not-found >/dev/null
sleep 20
run padrao # tracing 1%, sem access log
echo "FIM VAZAO"
