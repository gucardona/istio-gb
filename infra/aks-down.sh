#!/usr/bin/env bash
# Apaga TUDO (para o consumo de crédito). Rode sempre ao terminar.
set -euo pipefail
az group delete -n "${RG:-rg-istio-gb}" --yes --no-wait
