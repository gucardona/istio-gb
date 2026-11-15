#!/usr/bin/env bash
# Linhas não vazias e sem comentário: o que cada modo precisa para as MESMAS funções.
# Uso (raiz do repo):  ./bench/loc.sh
n() { cat "$@" | grep -vcE '^\s*(#|//|$)'; }
row() { printf "%-46s %5s\n" "$1" "$2"; }
echo "MODO B - funções no código Go (por linguagem/serviço)"
row "mtls.go (mTLS + autorização por identidade)"            "$(n app/mtls.go)"
row "resilience.go (timeout, retry, circuit breaker)"        "$(n app/resilience.go)"
row "metrics.go (métricas Prometheus)"                       "$(n app/metrics.go)"
row "infra/gen-certs.sh (CA + certificados + Secrets)"       "$(n infra/gen-certs.sh)"
row "TOTAL B (código + automação de certificados)"           "$(( $(n app/mtls.go app/resilience.go app/metrics.go infra/gen-certs.sh) ))"
echo
echo "MODO C - Istio (YAML, igual para qualquer linguagem)"
row "s3-strict.yaml (mTLS obrigatório)"                      "$(n k8s/s3-strict.yaml)"
row "s3-authz.yaml (autorização por identidade)"             "$(n k8s/s3-authz.yaml)"
row "s2-timeout-only.yaml (timeout + retry)"                 "$(n k8s/s2-timeout-only.yaml)"
row "s2-circuit-breaker.yaml (circuit breaker)"              "$(n k8s/s2-circuit-breaker.yaml)"
row "label istio-injection no namespace"                     "1"
row "TOTAL C"                                                "$(( $(n k8s/s3-strict.yaml k8s/s3-authz.yaml k8s/s2-timeout-only.yaml k8s/s2-circuit-breaker.yaml) + 1 ))"
echo
echo "Observações: C não inclui métricas (já vêm dos sidecars sem configuração) nem rotação de certificados (istiod)."
echo "B vale para UM serviço em Go; um serviço em outra linguagem repetiria o trabalho, no C não."
