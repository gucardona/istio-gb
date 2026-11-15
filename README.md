# Istio na prática (Sistemas Distribuídos, UNISINOS, Grau B)

Gustavo Parcianello Cardona e Danielle Toma. Prof. Rodrigo da Rosa Righi.

A mesma cadeia de microsserviços em Go (frontend, catalog v1/v2, inventory) roda no AKS de três formas:

- **A (`plain`)**: HTTP simples.
- **B (`applib`)**: mTLS, autorização, tempo limite, nova tentativa, circuit breaker e métricas escritos em Go.
- **C (`mesh`)**: Istio 1.26 em modo sidecar faz o mesmo por configuração YAML.

## Pastas

| Pasta | Conteúdo |
|---|---|
| `app/` | Código Go dos serviços (uma imagem para os três casos) |
| `k8s/` | Manifests dos três casos e regras do Istio |
| `infra/` | Scripts do AKS, Istio, imagem e observabilidade |
| `bench/` | Testes de carga (fortio) e agregação dos resultados |
| `results/` | Resultados brutos (JSON e logs) |
| `evidencias/` | Capturas de tela e documento de evidências |
| `paper/` | Artigo em LaTeX (modelo SBC) |
| `slides/` | Fonte dos slides da apresentação |
| `tools/` | Scripts de capturas e geração de documentos |

## Reproduzir (WSL)

```bash
./infra/aks-up.sh            # grupo, ACR (nome salvo em .acr-name) e AKS com 3 nós
./infra/istio-install.sh     # Istio 1.26 + Prometheus, Grafana, Jaeger, Kiali
./infra/build-image.sh       # compila o Go e envia a imagem ao ACR
kubectl apply -f k8s/namespaces.yaml -f k8s/clients.yaml
IMG="$(cat .acr-name).azurecr.io/svc:v1"
for ns in plain mesh; do sed "s|__IMG__|$IMG|" k8s/app.yaml.tpl | kubectl -n $ns apply -f -; done
./bench/prep-applib.sh       # caso B: certificados e namespace applib
./bench/run-compare.sh       # comparativo A/B/C -> results/cmp
./infra/aks-down.sh          # apaga tudo
```
