#!/usr/bin/env bash
# Liga o envio de spans dos sidecars para o Jaeger (addon), via provedor zipkin no meshConfig.
# O istiod relê o ConfigMap sozinho e empurra a config por xDS: sem reiniciar pods.
set -euo pipefail
kubectl -n istio-system patch cm istio --type merge -p '{"data":{"mesh":"defaultConfig:\n  discoveryAddress: istiod.istio-system.svc:15012\ndefaultProviders:\n  metrics:\n  - prometheus\n  tracing:\n  - zipkin\nextensionProviders:\n- name: zipkin\n  zipkin:\n    service: zipkin.istio-system.svc.cluster.local\n    port: 9411\nenablePrometheusMerge: true\nrootNamespace: istio-system\ntrustDomain: cluster.local\n"}}'
kubectl apply -f - <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata: {name: tracing-100, namespace: istio-system}
spec: {tracing: [{providers: [{name: zipkin}], randomSamplingPercentage: 100}]}
EOF
