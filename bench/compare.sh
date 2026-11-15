#!/usr/bin/env bash
# Comparativo dos 3 modos:  plain (A: HTTP puro)  applib (B: funções no código Go)  mesh (C: Istio)
# Uso (raiz do repo, no WSL):  ./bench/compare.sh lat res sec
set -uo pipefail
export PATH="$PWD/istio-${ISTIO_VERSION:-1.26.0}/bin:$PATH"
OUT=${OUT:-results/cmp}; REPS=${REPS:-3}; MODES="plain applib mesh"
TLSF="-cacert /tls/ca.crt -cert /tls/tls.crt -key /tls/tls.key"

# ld <modo> <args do fortio...> <alvo>   (alvo = nome do serviço)
ld() { local m=$1 tgt=${@: -1}; local a=("${@:2:$#-2}")
  if [ "$m" = applib ]; then kubectl -n applib exec deploy/load -c fortio -- fortio load -quiet -json - $TLSF "${a[@]}" "https://$tgt:8080/"
  else kubectl -n "$m" exec deploy/load -c fortio -- fortio load -quiet -json - "${a[@]}" "http://$tgt:8080/"; fi; }
cu() { local m=$1; shift; local extra=""; [ "$m" = applib ] && extra="--cacert /tls/ca.crt --cert /tls/tls.crt --key /tls/tls.key"
  local sch=http; [ "$m" = applib ] && sch=https
  kubectl -n "$m" exec deploy/curl -c curl -- curl -s -m 5 $extra -o /dev/null -w "%{http_code}" "$sch://$1:8080/" 2>/dev/null || true; }
setenv() { kubectl -n applib set env "$@" >/dev/null; }
wait_app() { kubectl -n "$1" rollout status deploy/"$2" --timeout=120s >/dev/null; sleep 6; }
reset_mesh() { kubectl -n mesh delete virtualservice catalog inventory --ignore-not-found >/dev/null; kubectl -n mesh apply -f k8s/subsets.yaml >/dev/null; sleep 5; }

lat() { # custo de latência e CPU/RAM: 3 modos x (50, 500 req/s) x (1, 32 conexões); modos intercalados para diluir deriva
  reset_mesh
  mkdir -p "$OUT/lat"
  for r in $(seq "$REPS"); do for q in 50 500; do for c in 1 32; do for m in $MODES; do
    echo ">> lat $m q=$q c=$c rep=$r"
    f="$OUT/lat/${m}_q${q}_c${c}_r$r"
    ld "$m" -qps "$q" -c "$c" -t 30s frontend > "$f.json" &
    LP=$!; sleep 20; kubectl top pods --containers -n "$m" > "$f.top.txt" 2>/dev/null || true; wait $LP; sleep 3
  done; done; done; done
}

res() { # resiliência: falha de 2s em 50% das chamadas ao inventory (mesma falha nos 3), depois timeout/retry, depois circuit breaker
  mkdir -p "$OUT/res"
  for m in $MODES; do
    echo "== res $m"
    kubectl -n "$m" set env deploy/inventory FAULT_DELAY_PCT- FAULT_DELAY_MS- >/dev/null; [ "$m" = mesh ] && reset_mesh; wait_app "$m" inventory
    ld "$m" -qps 50 -c 64 -t 30s -allow-initial-errors frontend > "$OUT/res/${m}_1_base.json"
    kubectl -n "$m" set env deploy/inventory FAULT_DELAY_PCT=50 FAULT_DELAY_MS=2000 >/dev/null; wait_app "$m" inventory
    ld "$m" -qps 50 -c 64 -t 30s -allow-initial-errors frontend > "$OUT/res/${m}_2_fault.json"
    case $m in
      applib) setenv deploy/frontend RETRIES=1 PER_TRY_MS=500 TIMEOUT_MS=1000; wait_app applib frontend ;;
      mesh)   kubectl -n mesh apply -f k8s/s2-timeout-only.yaml >/dev/null; sleep 8 ;;
      plain)  : ;; # sem a função: nada a ligar (é o ponto do modo A)
    esac
    if [ "$m" != plain ]; then ld "$m" -qps 50 -c 64 -t 30s -allow-initial-errors frontend > "$OUT/res/${m}_3_fault_policy.json"; fi
    kubectl -n "$m" set env deploy/inventory FAULT_DELAY_PCT- FAULT_DELAY_MS- >/dev/null; wait_app "$m" inventory
    case $m in applib) setenv deploy/frontend RETRIES- PER_TRY_MS- TIMEOUT_MS-; wait_app applib frontend ;; mesh) reset_mesh ;; esac
    echo "== cb $m"
    ld "$m" -qps 0 -c 20 -t 10s -allow-initial-errors frontend > "$OUT/res/${m}_4_cb_off.json"
    case $m in
      applib) setenv deploy/frontend MAX_INFLIGHT=2 CB_FAILS=1; wait_app applib frontend ;;
      mesh)   kubectl -n mesh apply -f k8s/s2-circuit-breaker.yaml >/dev/null; sleep 8 ;;
    esac
    if [ "$m" != plain ]; then ld "$m" -qps 0 -c 20 -t 10s -allow-initial-errors frontend > "$OUT/res/${m}_5_cb_on.json"; fi
    case $m in applib) setenv deploy/frontend MAX_INFLIGHT- CB_FAILS-; wait_app applib frontend ;; mesh) reset_mesh ;; esac
  done
}

sec() { # segurança: quem consegue chamar o quê
  mkdir -p "$OUT"; f="$OUT/sec.txt"; : > "$f"
  p() { printf "%-8s %-58s %s\n" "$1" "$2" "$3" | tee -a "$f"; }
  p plain  "cliente sem credencial -> frontend"                 "$(cu plain frontend)"
  p plain  "cliente sem credencial -> catalog (sem autorização)" "$(cu plain catalog)"
  kubectl -n applib exec deploy/curl -c curl -- curl -s -m 5 --cacert /tls/ca.crt -o /dev/null -w "%{http_code}" https://frontend:8080/ > /tmp/_c 2>/dev/null; sc=$(cat /tmp/_c); rm -f /tmp/_c
  p applib "cliente sem certificado -> frontend (handshake recusado)" "${sc:-000}"
  p applib "cliente com certificado -> frontend"                "$(cu applib frontend)"
  p applib "cliente CN=client -> catalog (so CN=frontend pode)"  "$(cu applib catalog)"
  kubectl -n mesh apply -f k8s/s3-strict.yaml >/dev/null; kubectl -n mesh apply -f k8s/s3-authz.yaml >/dev/null; sleep 8
  p mesh   "cliente fora da malha -> frontend (mTLS STRICT)"     "$(kubectl -n legacy exec deploy/curl -c curl -- curl -s -m 5 -o /dev/null -w '%{http_code}' http://frontend.mesh:8080/ 2>/dev/null || true)"
  p mesh   "cliente na malha -> frontend"                       "$(cu mesh frontend)"
  p mesh   "cliente na malha (SA client) -> catalog (so frontend pode)" "$(cu mesh catalog)"
  kubectl -n mesh delete authorizationpolicy catalog-only-frontend --ignore-not-found >/dev/null; kubectl -n mesh apply -f k8s/s3-permissive.yaml >/dev/null
}

for t in "$@"; do "$t"; done
