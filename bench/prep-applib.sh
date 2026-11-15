#!/usr/bin/env bash
# Modo B: reconstrói a imagem, rotaciona os 3 modos para a mesma versão do binário e sobe o namespace applib.
set -euo pipefail
./infra/build-image.sh >/dev/null
IMG="$(cat .acr-name).azurecr.io/svc:v1"
kubectl apply -f k8s/namespaces.yaml >/dev/null
./infra/gen-certs.sh >/dev/null
sed "s|__IMG__|$IMG|" k8s/app-applib.yaml.tpl | kubectl -n applib apply -f -
for ns in mesh plain; do kubectl -n "$ns" rollout restart deploy/frontend deploy/catalog-v1 deploy/catalog-v2 deploy/inventory >/dev/null; done
for ns in applib mesh plain; do kubectl -n "$ns" rollout status deploy --timeout=300s | tail -1; done
kubectl get pods -A -o wide --no-headers | grep -E "^(applib|mesh|plain) " | awk '{print $1, $2, $3, $4, $7}' | column -t
