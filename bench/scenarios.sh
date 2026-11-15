#!/usr/bin/env bash
# Uso (da raiz do repo, no WSL):  ./bench/scenarios.sh prep s0 s1 s2 s3 s4
# Evidências em results/<cenário>/. Pré-requisito: infra/aks-up.sh e infra/istio-install.sh.
set -euo pipefail
export PATH="$PWD/istio-${ISTIO_VERSION:-1.26.0}/bin:$PATH"
OUT=${OUT:-results}; ACR=$(cat .acr-name); REPS=${REPS:-3}
load() { local ns=$1; shift; kubectl -n "$ns" exec deploy/load -c fortio -- fortio load -quiet -json - "$@"; }
load_e() { load "$@" -allow-initial-errors; }
curlns() { local ns=$1; shift; kubectl -n "$ns" exec deploy/curl -- curl -s -m 5 "$@"; }
reset_routing() { kubectl -n mesh delete virtualservice catalog inventory --ignore-not-found >/dev/null; kubectl -n mesh apply -f k8s/subsets.yaml >/dev/null; sleep 5; }

prep() {
  ./infra/build-image.sh
  IMG="$ACR.azurecr.io/svc:v1"
  kubectl apply -f k8s/namespaces.yaml
  for ns in mesh plain; do
    sed "s|__IMG__|$IMG|" k8s/app.yaml.tpl | kubectl -n "$ns" apply -f -
  done
  for ns in mesh plain legacy; do kubectl -n "$ns" apply -f k8s/clients.yaml; done
  kubectl -n mesh apply -f k8s/gateway.yaml -f k8s/subsets.yaml
  for ns in mesh plain; do kubectl -n "$ns" rollout status deploy --timeout=300s; done
  kubectl -n legacy rollout status deploy --timeout=300s
  mkdir -p "$OUT"; kubectl get pods -A -o wide > "$OUT/pods.txt"
}

s0() { # Custo da malha: mesma carga com e sem Istio, em dois níveis de carga (50 e 500 req/s)
  mkdir -p "$OUT/s0"
  for q in 50 500; do for ns in plain mesh; do for r in $(seq "$REPS"); do
    echo ">> s0 $ns qps=$q rep=$r"
    load "$ns" -qps "$q" -c 32 -t 40s "http://frontend:8080/" > "$OUT/s0/${ns}_q${q}_r$r.json" &
    LP=$!; sleep 30   # kubectl top atrasa: lê CPU/RAM aos 30s, com a carga ainda ativa
    kubectl top pods --containers -n "$ns" > "$OUT/s0/top_${ns}_q${q}_r$r.txt" || true
    kubectl top nodes > "$OUT/s0/nodes_${ns}_q${q}_r$r.txt" || true
    wait $LP; sleep 5
  done; done; done
}

s1() { # Canário por peso
  mkdir -p "$OUT/s1"
  for w in "100 0" "90 10" "50 50" "0 100"; do set -- $w
    W1=$1 W2=$2 envsubst < k8s/s1-canary.yaml.tpl | kubectl -n mesh apply -f - >/dev/null; sleep 8
    echo ">> s1 v1=$1 v2=$2"
    for i in $(seq 200); do curlns mesh frontend:8080/; echo; done | jq -r '.upstream.version' | sort | uniq -c > "$OUT/s1/split_${1}_${2}.txt"
    cat "$OUT/s1/split_${1}_${2}.txt"
  done
  reset_routing
}

s2() { # Resiliência: falha injetada, timeout/retry, circuit breaker
  mkdir -p "$OUT/s2"; reset_routing
  echo ">> s2 sem falha";      load mesh -qps 50 -c 64 -t 30s -allow-initial-errors http://frontend:8080/ > "$OUT/s2/1_baseline.json"
  kubectl -n mesh apply -f k8s/s2-fault.yaml >/dev/null; sleep 8
  echo ">> s2 com falha (atraso 2s em 50% no inventory)"; load mesh -qps 50 -c 64 -t 30s -allow-initial-errors http://frontend:8080/ > "$OUT/s2/2_fault.json"
  kubectl -n mesh apply -f k8s/s2-timeout.yaml >/dev/null; sleep 8
  echo ">> s2 falha + timeout/retry";        load mesh -qps 50 -c 64 -t 30s -allow-initial-errors http://frontend:8080/ > "$OUT/s2/3_fault_timeout.json"
  reset_routing
  echo ">> s2 circuit breaker: sem política"; load mesh -qps 0 -c 20 -t 10s -allow-initial-errors http://catalog:8080/ > "$OUT/s2/4_cb_off.json"
  kubectl -n mesh apply -f k8s/s2-circuit-breaker.yaml >/dev/null; sleep 8
  echo ">> s2 circuit breaker: com política"; load mesh -qps 0 -c 20 -t 10s -allow-initial-errors http://catalog:8080/ > "$OUT/s2/5_cb_on.json"
  kubectl -n mesh exec deploy/load -c istio-proxy -- pilot-agent request GET stats | grep -E "catalog.*(overflow|ejections_enforced_total)" > "$OUT/s2/5_cb_stats.txt" || true
  reset_routing
}

s3() { # Segurança: mTLS e autorização por identidade
  mkdir -p "$OUT/s3"; f="$OUT/s3/resultado.txt"; : > "$f"
  code() { curlns "$1" -o /dev/null -w "%{http_code}" "$2" || true; }
  kubectl -n mesh apply -f k8s/s3-permissive.yaml >/dev/null; sleep 8
  echo "PERMISSIVE  cliente fora da malha -> frontend: $(code legacy http://frontend.mesh:8080/)" | tee -a "$f"
  kubectl -n mesh apply -f k8s/s3-strict.yaml >/dev/null; sleep 8
  echo "STRICT      cliente fora da malha -> frontend: $(code legacy http://frontend.mesh:8080/)" | tee -a "$f"
  echo "STRICT      cliente na malha      -> frontend: $(code mesh http://frontend:8080/)" | tee -a "$f"
  kubectl -n mesh apply -f k8s/s3-authz.yaml >/dev/null; sleep 8
  echo "AUTHZ       cliente na malha (SA client) -> catalog:  $(code mesh http://catalog:8080/)" | tee -a "$f"
  echo "AUTHZ       frontend via malha -> catalog (200 esperado): $(code mesh http://frontend:8080/)" | tee -a "$f"
  istioctl proxy-config secret deploy/frontend -n mesh > "$OUT/s3/certs_frontend.txt" || true
  istioctl proxy-config secret deploy/frontend -n mesh -o json | jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | base64 -d | openssl x509 -noout -text | grep -E "URI:|Not (Before|After)|Issuer:" > "$OUT/s3/cert_spiffe.txt" || true
  kubectl -n mesh delete authorizationpolicy catalog-only-frontend --ignore-not-found >/dev/null
  kubectl -n mesh apply -f k8s/s3-permissive.yaml >/dev/null
}

s4() { # Observabilidade: gera tráfego e consulta o Prometheus; Kiali/Jaeger por captura de tela
  mkdir -p "$OUT/s4"; reset_routing
  kubectl -n istio-system port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 & PF=$!; sleep 4
  load mesh -qps 50 -c 8 -t 60s http://frontend:8080/ > "$OUT/s4/trafego.json"
  q() { curl -s "localhost:9090/api/v1/query" --data-urlencode "query=$2" | jq . > "$OUT/s4/$1.json"; }
  q requests 'sum by (source_workload,destination_workload,response_code)(istio_requests_total{reporter="source",destination_workload_namespace="mesh"})'
  q p95 'histogram_quantile(0.95,sum by (le,destination_workload)(rate(istio_request_duration_milliseconds_bucket{reporter="destination",destination_workload_namespace="mesh"}[2m])))'
  q mtls 'sum by (connection_security_policy,destination_workload)(istio_requests_total{reporter="destination",destination_workload_namespace="mesh"})'
  kill $PF
  echo "Capturas manuais: istioctl dashboard kiali (Graph > namespace mesh) e istioctl dashboard jaeger (serviço frontend). Salve em $OUT/s4/."
}

for t in "$@"; do "$t"; done
