#!/usr/bin/env bash
# Instala Istio (perfil default = sidecar) + addons de observabilidade (Prometheus, Grafana, Jaeger, Kiali).
set -euo pipefail
V=${ISTIO_VERSION:-1.26.0}
[ -d "istio-$V" ] || curl -sL https://istio.io/downloadIstio | ISTIO_VERSION=$V sh -
export PATH="$PWD/istio-$V/bin:$PATH"
istioctl install --set profile=default -y
kubectl apply -f "istio-$V/samples/addons"          # prometheus, grafana, jaeger, kiali
kubectl apply -f k8s/telemetry.yaml                 # 100% dos traces (demo)
kubectl -n istio-system rollout status deploy/istiod deploy/kiali deploy/prometheus --timeout=300s
