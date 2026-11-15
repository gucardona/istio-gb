#!/usr/bin/env bash
jq -r '.data.result[]|[.metric.destination_workload,.metric.connection_security_policy,.value[1]]|@tsv' results/s4/mtls.json
echo "--- PeerAuthentication atual:"; kubectl -n mesh get peerauthentication -o custom-columns=NAME:.metadata.name,MODE:.spec.mtls.mode --no-headers
echo "--- plain tem sidecar?"; kubectl -n plain get pod -l app=frontend -o jsonpath='{.items[0].spec.containers[*].name}'; echo
