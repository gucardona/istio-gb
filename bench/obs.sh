#!/usr/bin/env bash
# Mede a mesma carga por 3 olhares: cliente (fortio), Prometheus (histograma dos sidecars) e Loki (access log do Envoy).
set -uo pipefail
OUT=${OUT:-results/obs}; mkdir -p "$OUT"; C=${C:-32}
kubectl -n istio-system port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 & P1=$!
kubectl -n istio-system port-forward svc/loki 3100:3100 >/dev/null 2>&1 & P2=$!
trap 'kill $P1 $P2 2>/dev/null' EXIT; sleep 4
T0=$(date +%s)
kubectl -n mesh exec deploy/load -c fortio -- fortio load -quiet -json - -qps 50 -c "$C" -t 40s http://frontend:8080/ > "$OUT/fortio_c$C.json"
sleep 25   # espera a próxima coleta do Prometheus e o envio dos logs
pq() { curl -s -G localhost:9090/api/v1/query --data-urlencode "query=$1" | jq -r '.data.result[]|[.metric.destination_workload // .metric.source_workload, (.value[1]|tonumber|.*10|round/10)]|@tsv'; }
echo "== Prometheus: p50 da duração (ms) vista por cada sidecar de DESTINO (inclui o que vem depois dele na cadeia)"
pq 'histogram_quantile(0.5, sum by (le,destination_workload)(rate(istio_request_duration_milliseconds_bucket{reporter="destination",destination_workload_namespace="mesh"}[2m])))' | tee "$OUT/prom_dest_p50_c$C.tsv"
echo "== Prometheus: p50 vista pelo sidecar de ORIGEM (load -> frontend) = o que o cliente vê dentro da malha"
pq 'histogram_quantile(0.5, sum by (le,source_workload)(rate(istio_request_duration_milliseconds_bucket{reporter="source",source_workload="load",destination_workload_namespace="mesh"}[2m])))' | tee "$OUT/prom_src_p50_c$C.tsv"
echo "== Loki: p50 da duração (ms) no access log, requisições de ENTRADA (inbound) por app"
curl -s -G localhost:3100/loki/api/v1/query --data-urlencode 'query=quantile_over_time(0.5, {namespace="mesh",container="istio-proxy"} |= "inbound|" | pattern `[<_>] "<_> <_> <_>" <code> <_> <_> <_> "<_>" <_> <_> <dur> <_>` | __error__="" | unwrap dur [3m]) by (app)' | jq -r '.data.result[]|[.metric.app,.value[1]]|@tsv' | tee "$OUT/loki_dur_p50_c$C.tsv"
echo "== Loki: 3 linhas de access log (frontend)"
curl -s -G localhost:3100/loki/api/v1/query_range --data-urlencode 'query={namespace="mesh",container="istio-proxy",app="frontend"} |= "inbound|"' --data-urlencode "start=$T0" --data-urlencode 'limit=3' | jq -r '.data.result[0].values[]?[1]' | cut -c1-330
echo "== fortio (cliente): p50/p99 ms"
jq -r '[(.DurationHistogram.Percentiles[]|select(.Percentile==50 or .Percentile==99)|.Value*1000|.*10|round/10)]|@tsv' "$OUT/fortio_c$C.json"
