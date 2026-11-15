#!/usr/bin/env bash
# Cota de vCPU por região (total e família DSv5). Uso: LOCS="eastus2 westus3" ./infra/quota.sh
for p in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.Compute Microsoft.Network; do az provider register -n "$p" >/dev/null 2>&1; done
for l in ${LOCS:-brazilsouth eastus eastus2 westus2 westus3 centralus southcentralus northeurope westeurope canadacentral}; do
  printf "%s: " "$l"
  az vm list-usage -l "$l" -o json 2>/dev/null | jq -r '[.[]|select(.name.value=="cores" or .name.value=="standardDSv5Family" or .name.value=="standardDASv5Family")|"\(.name.value) \(.currentValue)/\(.limit)"]|join(" | ")'
done
