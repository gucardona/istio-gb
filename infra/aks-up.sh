#!/usr/bin/env bash
# Cota Azure for Students: 6 vCPU no total e DSv5 zerada -> 3 nós de 2 vCPU (sys: D2ds_v4; app e load: D2s_v4).
set -euo pipefail
RG=${RG:-rg-istio-gb}; LOC=${LOC:-brazilsouth}; CL=${CL:-aks-istio-gb}
ACR=${ACR:-acristiogb$(echo -n "$(az account show --query id -o tsv)" | cksum | cut -d' ' -f1)}
az group create -n "$RG" -l "$LOC" -o none
az acr create -g "$RG" -n "$ACR" --sku Basic -o none
az aks create -g "$RG" -n "$CL" --tier free --location "$LOC" --attach-acr "$ACR" \
  --node-count 1 --node-vm-size Standard_D2ds_v4 --nodepool-name sys \
  --network-plugin azure --generate-ssh-keys -o none
for p in app load; do
  az aks nodepool add -g "$RG" --cluster-name "$CL" -n "$p" --node-count 1 --node-vm-size Standard_D2s_v4 \
    --labels role="$p" -o none
done
az aks get-credentials -g "$RG" -n "$CL" --overwrite-existing
echo "$ACR" > .acr-name
kubectl get nodes -o wide
