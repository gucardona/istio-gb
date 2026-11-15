#!/usr/bin/env bash
# Sem Docker e sem ACR Tasks (bloqueado em assinatura de estudante): compila o binário Go e empurra
# como camada sobre gcr.io/distroless/static usando crane.
set -euo pipefail
ACR=$(cat .acr-name); IMG="$ACR.azurecr.io/svc:v1"
export PATH="$HOME/bin:$PATH"
command -v crane >/dev/null || { mkdir -p "$HOME/bin"; curl -sL https://github.com/google/go-containerregistry/releases/download/v0.20.3/go-containerregistry_Linux_x86_64.tar.gz | tar xz -C "$HOME/bin" crane; }
T=$(mktemp -d); trap 'rm -rf $T' EXIT
GOBIN=$(command -v go || echo "/mnt/c/Program Files/Go/bin/go.exe")
( cd app && WSLENV=GOOS:GOARCH:CGO_ENABLED GOOS=linux GOARCH=amd64 CGO_ENABLED=0 "$GOBIN" build -o svc . ) && mv app/svc "$T/svc"
tar -C "$T" -cf "$T/layer.tar" svc
az acr login -n "$ACR" --expose-token --output tsv --query accessToken | \
  crane auth login "$ACR.azurecr.io" -u 00000000-0000-0000-0000-000000000000 --password-stdin
crane append -b gcr.io/distroless/static:latest -f "$T/layer.tar" -t "$IMG" >/dev/null
crane mutate "$IMG" --entrypoint /svc -t "$IMG" >/dev/null
crane manifest "$IMG" | head -c 200; echo; echo "imagem: $IMG"
