#!/usr/bin/env bash
# Modo B: cria uma CA própria e um certificado por serviço (CN = nome do serviço) como Secrets no namespace applib.
# Isso é o trabalho que, no Istio, o istiod faz sozinho (emissão e rotação).
set -euo pipefail
NS=${NS:-applib}; D=$(mktemp -d); trap 'rm -rf $D' EXIT; cd "$D"
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -subj "/CN=applib-ca" -days 365 2>/dev/null
for s in frontend catalog inventory client; do
  openssl req -newkey rsa:2048 -nodes -keyout "$s.key" -out "$s.csr" -subj "/CN=$s" 2>/dev/null
  printf "subjectAltName=DNS:%s,DNS:%s.%s,DNS:%s.%s.svc,DNS:%s.%s.svc.cluster.local\nextendedKeyUsage=serverAuth,clientAuth\n" "$s" "$s" "$NS" "$s" "$NS" "$s" "$NS" > "$s.ext"
  openssl x509 -req -in "$s.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -out "$s.crt" -days 365 -extfile "$s.ext" 2>/dev/null
  kubectl -n "$NS" create secret generic "tls-$s" --from-file=tls.crt="$s.crt" --from-file=tls.key="$s.key" --from-file=ca.crt=ca.crt --dry-run=client -o yaml | kubectl apply -f -
done
