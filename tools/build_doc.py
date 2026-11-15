#!/usr/bin/env python3
"""Monta evidencias/evidencias-istio-gb.docx (texto + figuras + tabelas) a partir de results/ e evidencias/.
Uso (raiz do repo, WSL):  python3 tools/build_doc.py   -> depois sobe para o Drive convertido em Google Doc."""
import json, re
from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor

E = Path("evidencias")
S = json.loads(Path("results/cmp/summary.json").read_text())
doc = Document()
doc.styles["Normal"].font.name = "Arial"
doc.styles["Normal"].font.size = Pt(11)

H = doc.add_heading
def P(text, bold_lead=None):
    p = doc.add_paragraph()
    if bold_lead:
        p.add_run(bold_lead).bold = True
    p.add_run(text)
    return p
def B(*items):
    for t in items:
        doc.add_paragraph(t, style="List Bullet")
def code(text):
    p = doc.add_paragraph()
    r = p.add_run(text.rstrip())
    r.font.name = "Courier New"; r.font.size = Pt(8)
def table(head, rows):
    t = doc.add_table(rows=1, cols=len(head)); t.style = "Light Grid Accent 1"
    for c, h in zip(t.rows[0].cells, head):
        c.text = h; c.paragraphs[0].runs[0].bold = True
    for r in rows:
        for c, v in zip(t.add_row().cells, r):
            c.text = str(v)
    doc.add_paragraph()
fig_n = [0]
def fig(name, title, shows, why):
    fig_n[0] += 1
    doc.add_picture(str(E / f"{name}.png"), width=Inches(6.3))
    cap = doc.add_paragraph(); r = cap.add_run(f"Figura {fig_n[0]} – {title}"); r.bold = True; r.font.size = Pt(10)
    P(shows, "O que mostra: ")
    P(why, "Por que importa: ")

# ---------------------------------------------------------------- capa
H("Istio na prática: mTLS, controle de tráfego e observabilidade em microsserviços Go no Kubernetes", 0)
P("Trabalho do Grau B – Sistemas Distribuídos (UNISINOS) – Prof. Rodrigo da Rosa Righi")
P("Gustavo Parcianello Cardona e Danielle Toma")
P("Documento de evidências: base para a apresentação (aula 16) e para o artigo em LaTeX (modelo SBC). "
  "Cada figura traz o que mostra e por que importa; os números vêm das execuções no cluster AKS.")

# ---------------------------------------------------------------- 1
H("1. Estratégia", 1)
P("No GA escolhemos o Istio como middleware. No GB implementamos um protótipo para mostrar, com medições, "
  "o que o Istio facilita na comunicação entre microsserviços: segurança (mTLS e autorização por identidade), "
  "controle de tráfego (canário, timeout, retry, circuit breaker) e observabilidade (métricas, logs e traces) — "
  "sem mudar o código da aplicação.")
P("Para a comparação ser justa, o mesmo serviço Go roda de três formas:")
B("A – HTTP puro (namespace plain): sem segurança nem resiliência. Linha de base de custo.",
  "B – Funções no código (namespace applib): mTLS com crypto/tls, autorização por CN do certificado, timeout, retry, "
  "circuit breaker, limite de concorrência e métricas Prometheus, tudo escrito em Go.",
  "C – Istio (namespace mesh): o mesmo binário com essas funções desligadas; o sidecar Envoy faz tudo, configurado por YAML.")
P("A mesma imagem de contêiner é usada nos três modos; só variam variáveis de ambiente e o label de injeção do namespace.")

# ---------------------------------------------------------------- 2
H("2. Arquitetura e infraestrutura", 1)
B("Cadeia de 3 serviços Go: frontend → catalog (v1 e v2) → inventory. Cada requisição atravessa 3 saltos.",
  "Kubernetes gerenciado: Azure AKS (brazilsouth), Kubernetes 1.36, 3 nós de 2 vCPU: sistema (D2ds_v4), "
  "aplicação (D2s_v4, role=app) e carga (D2s_v4, role=load). O gerador de carga fica em nó separado para não disputar CPU com os serviços.",
  "Istio 1.26.0, modo sidecar, perfil default (istiod + ingress gateway).",
  "Observabilidade: Prometheus, Grafana (dashboards do Istio), Kiali, Jaeger e Loki (logs coletados por Grafana Alloy).",
  "Carga: fortio 1.69.5 (req/s fixas, número de conexões, duração, saída JSON).",
  "Código: Go 1.22 só com a biblioteca padrão; imagem distroless publicada no Azure Container Registry.")
table(["Componente", "Versão / configuração"], [
    ["Istio", "1.26.0, sidecar, perfil default"], ["Kubernetes", "AKS 1.36, 3 nós × 2 vCPU"],
    ["Serviços", "frontend, catalog v1/v2, inventory (Go, mesma imagem)"], ["Carga", "fortio 1.69.5"],
    ["Observabilidade", "Prometheus, Grafana, Kiali, Jaeger, Loki + Alloy"]])

# ---------------------------------------------------------------- 3
H("3. O papel do Istio, visto pelo kubectl", 1)
P("Saída real de demo/istio-demo.sh no cluster. Mostra como o Istio se encaixa no Kubernetes sem tocar na aplicação:")
B("Um label no namespace (istio-injection=enabled) faz o webhook do istiod injetar o sidecar: o pod passa de 1/1 para 2/2 contêineres.",
  "O initContainer istio-init cria regras iptables que mandam todo tráfego de entrada (porta 15006) e saída (15001) para o Envoy. A aplicação continua falando HTTP simples em localhost.",
  "O istiod distribui configuração aos Envoys por xDS (CDS, LDS, EDS, RDS); o proxy-status mostra todos sincronizados.",
  "Cada workload recebe uma identidade SPIFFE (spiffe://cluster.local/ns/mesh/sa/frontend) num certificado X.509 de 24 h, renovado automaticamente.",
  "As métricas L7 (istio_requests_total) saem do sidecar, com origem, destino e identidade, sem instrumentação na aplicação.")
code(re.sub(r"\x1b\[[0-9;]*m", "", Path("results/demo.txt").read_text()))

# ---------------------------------------------------------------- 4
H("4. Evidências visuais", 1)
P("Capturas feitas com tráfego constante de 30 req/s no namespace mesh (fortio → frontend → catalog → inventory).")
H("4.1 Kiali – topologia e segurança", 2)
fig("01-kiali-seguranca", "Kiali: grafo com mTLS em todas as arestas",
    "Grafo do namespace mesh gerado só com a telemetria dos sidecars. Cada aresta tem um cadeado: a conexão entre os serviços usou mTLS.",
    "Ninguém escreveu código de TLS nem distribuiu certificados para os serviços. O Istio cifrou e autenticou o tráfego entre eles, e o Kiali deixa isso visível.")
fig("02-kiali-distribuicao", "Kiali: divisão do tráfego entre catalog v1 e v2",
    "Percentual de requisições que o Service catalog mandou para cada versão (cerca de 50% / 50% sem regra de peso).",
    "É a base do canário: com um VirtualService os pesos passam a ser 90/10, 100/0 etc., sem mexer em réplicas nem no código (ver seção 6).")
fig("03-kiali-latencia", "Kiali: tempo de resposta (p95) por aresta",
    "O p95 de cada salto: o frontend responde em cerca de 24 ms, o catalog em cerca de 16–17 ms e o inventory em cerca de 5 ms.",
    "Mostra onde o tempo se acumula na cadeia sem nenhum APM instalado na aplicação.")
fig("04-kiali-workloads", "Kiali: workloads saudáveis e política de mTLS aplicada",
    "Todos os workloads saudáveis, com labels app/version e a PeerAuthentication (PA default) que vale para eles.",
    "O Kiali também valida configuração: aponta, por exemplo, os workloads sem label de versão (load e curl, que são clientes de teste).")
fig("05-kiali-config-istio", "Kiali: objetos de configuração do Istio no namespace",
    "Telemetry (access-log), DestinationRule (subsets v1/v2), PeerAuthentication, VirtualService e Gateway, todos validados.",
    "Toda a política da malha é declarativa (CRDs do Kubernetes), versionável em Git e aplicada com kubectl apply.")

H("4.2 Grafana e Prometheus – métricas sem instrumentar a aplicação", 2)
fig("06-grafana-servico", "Grafana: Istio Service Dashboard (frontend)",
    "Volume (30 req/s), taxa de sucesso (100%) e duração P50/P90/P99 do frontend, vistas pelo cliente e pelo servidor.",
    "São os 'golden signals' prontos para qualquer serviço que entre na malha, em qualquer linguagem.")
fig("07-grafana-workload", "Grafana: Istio Workload Dashboard (frontend)",
    "Mesmas métricas por workload, com quem chama o frontend e com que código de resposta.",
    "Mostra a origem do tráfego de entrada, útil para achar o cliente que gera erros.")
fig("08-grafana-malha", "Grafana: Istio Mesh Dashboard",
    "Visão global: 90 req/s somando os 3 saltos, 0 erros 4xx/5xx e tabela de P50/P90/P99 por serviço.",
    "Visão de toda a malha em uma tela, sem configuração por serviço.")
fig("09-grafana-plano-controle", "Grafana: Istio Control Plane Dashboard",
    "Memória, CPU e goroutines do istiod e os pushes xDS para os proxies.",
    "O plano de controle é pequeno (cerca de 50 MiB, CPU quase zero) e fica fora do caminho dos dados: as requisições não passam pelo istiod.")
fig("11-prometheus-requisicoes", "Prometheus: requisições por workload",
    "rate(istio_requests_total) por destino: frontend e inventory com 30 req/s; catalog-v1 e v2 com 15 req/s cada.",
    "A métrica bruta que alimenta Grafana e Kiali, consultável em PromQL.")
fig("12-prometheus-p95", "Prometheus: latência p95 por workload",
    "histogram_quantile(0.95) sobre istio_request_duration_milliseconds por workload.",
    "Permite alertas de SLO por serviço sem nenhuma biblioteca de métricas na aplicação.")

H("4.3 Loki – logs de acesso", 2)
fig("10-loki-access-log", "Loki (via Grafana): access log do Envoy",
    "Logs do contêiner istio-proxy no namespace mesh, filtrados por 'inbound'. Cada linha traz método, caminho, código, bytes, duração, x-request-id e IPs de origem/destino.",
    "Um log de acesso padronizado para todos os serviços, ligado com um recurso Telemetry, e correlacionável com traces pelo x-request-id.")

H("4.4 Jaeger – rastreamento distribuído", 2)
fig("13-jaeger-busca", "Jaeger: traces do frontend",
    "Lista de traces com os spans de frontend, catalog e inventory em cada requisição.",
    "Os spans são criados pelos sidecars. A aplicação só repassa os cabeçalhos de trace (x-request-id, traceparent, x-b3-*), o único trabalho que o tracing exige dela.")
fig("14-jaeger-trace", "Jaeger: uma requisição atravessando os 3 serviços",
    "Linha do tempo com 6 spans: load → frontend → catalog → inventory, com a duração de cada salto (inventory 1,9 ms; catalog 18,4 ms; frontend 24,6 ms).",
    "Mostra, para uma requisição, quanto cada salto e cada proxy somou. O span do load aparece deslocado por diferença de relógio entre nós.")

# ---------------------------------------------------------------- 5
H("5. Comparativo A × B × C", 1)
H("5.1 Metodologia", 2)
B("Latência: 2 taxas (50 e 500 req/s) × 2 níveis de concorrência (1 e 32 conexões) × 3 modos × 3 rodadas de 30 s. "
  "Os modos são intercalados em cada rodada para diluir variações do ambiente. Valores = mediana das 3 rodadas.",
  "CPU/RAM: kubectl top no meio de cada rodada, somando só os pods da cadeia (frontend, catalog, inventory, incluindo os sidecars em C).",
  "Resiliência: a falha vem da própria aplicação nos 3 modos (inventory atrasa 2 s em 50% das chamadas). "
  "Política igual em B e C: timeout total de 1 s e 1 retentativa de 500 ms. Carga: 50 req/s, 64 conexões, 30 s.",
  "Circuit breaker: carga sem limite de taxa com 20 conexões por 10 s, antes e depois de ligar o limite "
  "(B: MAX_INFLIGHT=2 e CB_FAILS=1; C: DestinationRule com maxConnections 1 e outlier detection).",
  "Segurança: chamadas com e sem credencial, testando quem consegue chamar o quê.")

H("5.2 Latência e recursos", 2)
rows = []
for q in (50, 500):
    for c in (1, 32):
        for m, lab in (("plain", "A"), ("applib", "B"), ("mesh", "C")):
            r = S["lat"][f"{m}_q{q}_c{c}"]
            rows.append([lab, q, c, f"{r['qps']:.0f}", f"{r['p50']:.1f}", f"{r['p90']:.1f}", f"{r['p99']:.1f}", r["cpu"], r["mem"]])
table(["Modo", "req/s alvo", "conexões", "req/s obtidas", "p50 ms", "p90 ms", "p99 ms", "CPU (m)", "RAM (Mi)"], rows)
fig("15-cmp-latencia", "Latência p50 e p99 fim a fim nos três modos",
    "Com 1 conexão, B fica igual a A (mTLS no Go custa menos de 0,1 ms) e C soma cerca de 2–3 ms nos 3 saltos (cerca de 1 ms por salto). "
    "Com 32 conexões, A e B ficam em cerca de 8 ms e C chega a cerca de 46 ms no p50 e a 100–130 ms no p99.",
    "O custo do Istio não vem da criptografia (B também usa mTLS e quase não muda): vem dos proxies extras (2 Envoys por salto) e da telemetria, "
    "e cresce muito com a concorrência em nós de 2 vCPU.")
P("Leituras importantes:")
B("A 500 req/s com 1 conexão, C entregou cerca de 309 req/s: com cerca de 3,2 ms por requisição, uma única conexão sequencial não chega a 500 req/s.",
  "RAM: C usa cerca de 190 Mi contra cerca de 30 Mi de A/B, porque cada sidecar ocupa 35–45 Mi (6 pods na cadeia mais o cliente).",
  "CPU: em 500 req/s com 32 conexões, C usou cerca de 165 m contra 34 m (A) e 74 m (B). As amostras do kubectl top têm ruído; usamos a mediana e tratamos a CPU como ordem de grandeza.")

H("5.3 Resiliência (timeout e retry)", 2)
R = S["res"]
lab = {"1_base": "sem falha", "2_fault": "falha 2 s em 50%", "3_fault_policy": "falha + timeout/retry"}
rows = []
for m, ml in (("plain", "A"), ("applib", "B"), ("mesh", "C")):
    for k, kl in lab.items():
        r = R.get(f"{m}_{k}")
        if r:
            ok = r["codes"].get("200", 0); tot = sum(r["codes"].values())
            rows.append([ml, kl, f"{r['avg']:.0f}", f"{r['p50']:.0f}", f"{r['p99']:.0f}", f"{100*ok/tot:.0f}%", ", ".join(f"{k2}:{v}" for k2, v in r["codes"].items())])
        else:
            rows.append([ml, kl, "–", "–", "–", "–", "sem a função"])
table(["Modo", "Fase", "média ms", "p50 ms", "p99 ms", "sucesso", "códigos"], rows)
fig("16-cmp-resiliencia", "Latência p99 com o inventory lento",
    "Sem política, os 3 modos esperam os 2 s da falha (p99 ≈ 2 s). Com timeout de 1 s e 1 retentativa, B e C limitam o p99 a cerca de 1,1–1,3 s e cortam a média pela metade (de cerca de 1 s para cerca de 500 ms).",
    "B e C se comportam igual (cerca de 75% de sucesso, o esperado: 1 − 0,5² com uma retentativa). "
    "A diferença está no custo: B precisou de cerca de 120 linhas de Go em resilience.go; C precisou de 9 linhas de YAML, que valem para qualquer linguagem.")
P("Trocar espera por erro rápido (504) é o objetivo: o cliente não fica preso 2 s e pode decidir o que fazer. A não tem como fazer isso sem mudar o código.")

H("5.4 Circuit breaker", 2)
rows = []
for m, ml in (("plain", "A"), ("applib", "B"), ("mesh", "C")):
    for k, kl in (("4_cb_off", "desligado"), ("5_cb_on", "ligado")):
        r = R.get(f"{m}_{k}")
        if r:
            tot = sum(r["codes"].values()); rej = r["codes"].get("503", 0)
            rows.append([ml, kl, f"{r['qps']:.0f}", f"{r['p50']:.1f}", f"{r['p99']:.1f}", f"{100*rej/tot:.0f}%"])
        else:
            rows.append([ml, kl, "–", "–", "–", "sem a função"])
table(["Modo", "CB", "req/s", "p50 ms", "p99 ms", "rejeitadas (503)"], rows)
B("Com o limite ligado, B rejeitou 66% e C 89% das requisições com 503 imediato. É o comportamento esperado: protege o serviço de cima e falha rápido (fail-fast).",
  "Sem limite de taxa, A chegou a cerca de 3.800 req/s e B a cerca de 3.450 req/s, enquanto C ficou em cerca de 560 req/s. Este é o teto de vazão dos sidecars nesse hardware (2 vCPU por nó, 2 Envoys por salto).")

H("5.5 Segurança", 2)
sec = [l.split(None, 1) for l in Path("results/cmp/sec.txt").read_text().splitlines() if l.strip()]
table(["Modo", "Teste", "HTTP"], [[a, *b.rsplit(None, 1)] for a, b in sec])
B("A: qualquer pod alcança qualquer serviço (200 em tudo). Não há identidade nem cifragem.",
  "B: sem certificado o handshake falha (000); com certificado entra; CN=client é barrado no catalog (403) por código Go.",
  "C: com PeerAuthentication STRICT, um pod fora da malha é recusado (000); dentro da malha passa; a AuthorizationPolicy deixa só a service account frontend chamar o catalog (403 para as outras).",
  "Mesmo resultado em B e C. Em C, porém, os certificados são emitidos e renovados a cada 24 h pelo istiod. Em B, a CA e os certificados foram gerados à mão (gen-certs.sh) e não têm rotação.")

H("5.6 Esforço de implementação", 2)
table(["Função", "B: código Go / script (linhas)", "C: YAML do Istio (linhas)"], [
    ["mTLS + autorização por identidade", "46 (mtls.go)", "12 (strict + authz)"],
    ["timeout + retry + circuit breaker", "120 (resilience.go)", "18"],
    ["métricas", "52 (metrics.go)", "0 (vêm do sidecar)"],
    ["certificados", "9 (gen-certs.sh), sem rotação", "0 (istiod, rotação automática)"],
    ["injeção", "–", "1 (label no namespace)"],
    ["TOTAL", "227, por linguagem", "31, vale para qualquer linguagem"]])

# ---------------------------------------------------------------- 6
H("6. Canário (divisão de tráfego por peso)", 1)
table(["Pesos no VirtualService (v1/v2)", "200 requisições: v1", "v2"],
      [["100/0", 200, 0], ["90/10", 190, 10], ["50/50", 104, 96], ["0/100", 0, 200]])
P("A divisão observada segue os pesos configurados. A troca de versão é feita com kubectl apply de um VirtualService, sem alterar réplicas, Service ou código.")

# ---------------------------------------------------------------- 7
H("7. Discussão", 1)
B("O Istio entrega as mesmas garantias de segurança e resiliência do modo B, com cerca de 7× menos configuração, independente de linguagem, e com rotação de certificados e observabilidade que B não tem.",
  "O preço é recurso e latência: cerca de 1 ms por salto em baixa concorrência, dezenas de ms com 32 conexões em nós pequenos, cerca de 6× mais memória na cadeia e teto de vazão bem menor.",
  "O custo não vem do mTLS (B prova que TLS em Go é quase de graça); vem dos proxies extras e da telemetria. Esse é o argumento para o modo ambient (ztunnel L4 + waypoint L7 só onde precisa), visto no GA.",
  "Para sistemas com muitos serviços e linguagens, o ganho operacional (políticas centralizadas, auditoria, zero-trust) compensa. Para poucos serviços sensíveis a latência, o modo B ou o ambient podem ser melhores.")

H("8. Limitações", 1)
B("Ambiente pequeno (3 nós de 2 vCPU, cota do Azure for Students): os valores absolutos de latência sob concorrência dependem do hardware; o que vale é a comparação relativa.",
  "Não isolamos a causa exata do aumento com 32 conexões; a hipótese mais provável é disputa de CPU no nó da aplicação, onde estão os sidecars.",
  "CPU via kubectl top (metrics-server) tem amostragem grosseira; a RAM é estável.",
  "Só 3 rodadas por configuração e uma única topologia (3 saltos).",
  "Apenas o modo sidecar; ambient não foi medido.",
  "O modo B usa certificados estáticos, sem rotação, o que favorece B no esforço de implementação.")

H("9. Reprodutibilidade", 1)
code("infra/aks-up.sh         # cria RG, ACR e AKS\ninfra/istio-install.sh  # Istio 1.26 + addons\ninfra/tracing.sh        # Jaeger via provedor zipkin\n"
     "bench/scenarios.sh prep # imagem + deploy\nbench/run-compare.sh    # comparativo A/B/C -> results/cmp\n"
     "python3 bench/cmp_summary.py && python3 bench/cmp_plots.py\ndemo/istio-demo.sh      # demonstração kubectl\n"
     "node tools/shots.mjs    # capturas -> evidencias/\ninfra/aks-down.sh       # apaga tudo")

out = E / "evidencias-istio-gb.docx"
doc.save(out)
print(out)
