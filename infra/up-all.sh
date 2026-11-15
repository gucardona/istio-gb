#!/usr/bin/env bash
# Recria o ambiente inteiro do zero: AKS, Istio + painéis, imagem, os 3 casos e a telemetria das evidências.
# Uso (raiz do repo, no WSL, com `az login` feito):  ./infra/up-all.sh
# Depois: ./bench/run-compare.sh (comparativo), ./bench/vazao-telemetria.sh, ./infra/forwards.sh (painéis).
set -euo pipefail
cd "$(dirname "$0")/.."

./infra/aks-up.sh                 # grupo, ACR (.acr-name) e AKS com 3 nós
./infra/istio-install.sh          # Istio 1.26 + Prometheus, Grafana, Jaeger, Kiali, Loki
./infra/build-image.sh            # compila o Go e envia a imagem ao ACR
IMG="$(cat .acr-name).azurecr.io/svc:v1"

kubectl apply -f k8s/namespaces.yaml
for ns in plain mesh; do
  sed "s|__IMG__|$IMG|" k8s/app.yaml.tpl | kubectl -n "$ns" apply -f -
done
for ns in plain applib mesh; do kubectl -n "$ns" apply -f k8s/clients.yaml; done
kubectl -n mesh apply -f k8s/gateway.yaml -f k8s/subsets.yaml
./bench/prep-applib.sh            # caso B: certificados (Secrets) e deployments do applib

./infra/tracing.sh                # Jaeger recebe os traces (zipkin, 100%)
kubectl apply -f k8s/accesslog.yaml -f k8s/alloy.yaml   # log de acesso do Envoy -> Alloy -> Loki

for ns in plain applib mesh; do kubectl -n "$ns" rollout status deploy --timeout=300s; done
./infra/smoke.sh && ./infra/smoke-applib.sh
