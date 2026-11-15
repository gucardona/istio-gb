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

Precisa de `az`, `kubectl`, `go`, `crane` e `jq` no WSL, e de `az login` feito.

```bash
./infra/up-all.sh               # AKS, Istio, painéis, imagem, os 3 casos e a telemetria
./bench/run-compare.sh          # comparativo A/B/C -> results/cmp
./bench/vazao-telemetria.sh     # vazão do caso C com telemetria das evidências e no padrão
./infra/forwards.sh             # painéis em localhost (Kiali, Grafana, Jaeger, Prometheus, Loki)
./infra/aks-down.sh             # apaga tudo
```

Os resultados de uma nova execução vão variar um pouco: o que importa é a comparação entre os casos no mesmo ambiente.
