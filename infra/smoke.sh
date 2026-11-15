#!/usr/bin/env bash
for ns in plain mesh; do echo "== $ns"; kubectl -n $ns exec deploy/curl -- curl -s -m 5 -w "\nHTTP %{http_code}\n" frontend:8080/; done
