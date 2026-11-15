#!/usr/bin/env bash
# Demo "o que o Istio faz entre os apps". Só leitura. Rode da raiz do repo, no WSL.
export PATH="$PWD/istio-${ISTIO_VERSION:-1.26.0}/bin:$PATH"
h() { printf '\n\033[1m### %s\033[0m\n$ %s\n' "$1" "$2"; }
h "1. Mesmo código, duas malhas: no 'plain' cada pod tem 1 container; no 'mesh' tem 2 (app + istio-proxy)" "kubectl get pods -n plain / -n mesh"
kubectl get pods -n plain -l app=frontend; kubectl get pods -n mesh -l app=frontend
h "2. Quem decide a injeção: um label no namespace (webhook mutante do istiod)" "kubectl get ns mesh plain --show-labels"
kubectl get ns mesh plain --show-labels | cut -c1-110
h "3. O que o Kubernetes realmente criou no pod do mesh (o YAML nosso só tinha 1 container)" "kubectl get pod frontend -o jsonpath initContainers/containers"
kubectl -n mesh get pod -l app=frontend -o jsonpath='initContainers: {.items[0].spec.initContainers[*].name}{"\n"}containers:     {.items[0].spec.containers[*].name}{"\n"}'
h "4. O initContainer istio-init redireciona TODO tráfego do pod para o Envoy via iptables (a app nem sabe)" "kubectl get pod -o jsonpath (args do istio-init)"
kubectl -n mesh get pod -l app=frontend -o jsonpath='{.items[0].spec.initContainers[0].args}{"\n"}' | tr ',' ' ' | cut -c1-260
h "5. Plano de controle: um único istiod + ingress gateway" "kubectl get pods -n istio-system"
kubectl -n istio-system get pods | grep -E "NAME|istiod|ingressgateway"
h "6. A configuração do Istio são CRDs do Kubernetes (kubectl apply, versionável em Git)" "kubectl get virtualservice,destinationrule,peerauthentication,authorizationpolicy -n mesh"
kubectl -n mesh get virtualservice,destinationrule,peerauthentication,authorizationpolicy 2>&1 | cut -c1-110
h "7. O istiod empurra config para cada Envoy via xDS: todos sincronizados?" "istioctl proxy-status"
istioctl proxy-status 2>&1 | cut -c1-140 | grep -E "NAME|mesh"
h "8. O que o Envoy do frontend sabe sobre 'catalog' (service discovery vindo do K8s, não do DNS da app)" "istioctl proxy-config endpoints deploy/frontend -n mesh | grep catalog"
istioctl proxy-config endpoints deploy/frontend -n mesh 2>/dev/null | grep -E "ENDPOINT|catalog"
h "9. Identidade criptográfica do workload (SPIFFE, certificado X.509 de 24h, rotacionado sozinho)" "istioctl proxy-config secret deploy/frontend -n mesh"
istioctl proxy-config secret deploy/frontend -n mesh 2>/dev/null | cut -c1-110
h "10. Métricas L7 sem uma linha de instrumentação na app (vêm do sidecar)" "kubectl exec frontend -c istio-proxy -- pilot-agent request GET stats/prometheus | grep istio_requests_total"
kubectl -n mesh exec deploy/frontend -c istio-proxy -- pilot-agent request GET stats/prometheus 2>/dev/null | grep '^istio_requests_total' | head -3 | cut -c1-330
h "11. Mesma imagem nos 3 namespaces: no mesh a app roda com TLS, retry e métricas DESLIGADOS (só o modo applib liga por env)" "kubectl get deploy frontend -o jsonpath env (mesh vs applib)"
for n in mesh applib; do printf "%-7s " "$n"; kubectl -n "$n" get deploy frontend -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value} {end}'; echo; done
