#!/usr/bin/env bash
C="kubectl -n applib exec deploy/curl -- curl -s -m 5"
M="--cacert /tls/ca.crt --cert /tls/tls.crt --key /tls/tls.key"
echo "1) com certificado de cliente:"; $C $M -w "\nHTTP %{http_code}\n" https://frontend:8080/
echo "2) sem certificado de cliente (esperado: falha no handshake):"; $C --cacert /tls/ca.crt -o /dev/null -w "HTTP %{http_code}\n" https://frontend:8080/ || echo "curl saiu com erro (handshake recusado)"
echo "3) HTTP puro na porta TLS (esperado: erro):"; $C -o /dev/null -w "HTTP %{http_code}\n" http://frontend:8080/ || true
echo "4) client -> catalog direto (CN=client nao esta em ALLOWED_CLIENTS; esperado 403):"; $C $M -o /dev/null -w "HTTP %{http_code}\n" https://catalog:8080/
echo "5) metricas do frontend:"; $C $M https://frontend:8080/metrics | head -4
