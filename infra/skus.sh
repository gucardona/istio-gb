#!/usr/bin/env bash
# Tamanhos de 2 vCPU disponíveis (sem restrição) para a assinatura em cada região.
for l in ${LOCS:-brazilsouth eastus2 westus3 centralus}; do
  echo "== $l"
  az vm list-skus -l "$l" --resource-type virtualMachines --size Standard_D2 -o json 2>/dev/null | \
   jq -r '.[] | select((.restrictions|length)==0) | .name' | grep -E "^Standard_D2(as_v4|s_v3|_v2|s_v4|_v3|ads_v5|s_v5)$" | tr "\n" " "; echo
done
