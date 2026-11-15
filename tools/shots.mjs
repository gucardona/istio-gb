// Captura os painéis (Kiali, Grafana, Prometheus, Jaeger) em PNG para ../evidencias.
// Uso:  node shots.mjs            (todas)    |    node shots.mjs kiali-seguranca grafana-servico   (algumas)
// Pré-requisito: infra/forwards.sh rodando e tráfego passando pelo namespace mesh.
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";

const K = "http://localhost:20001/kiali/console";
const G = "http://localhost:3000";
const LOKI = "P8E80F9AEF21F6940";
const kiali = (q) => `${K}/graph/namespaces/?namespaces=mesh&graphType=versionedApp&duration=300&refresh=0&${q}`;
const loki = JSON.stringify({ a: { datasource: LOKI, queries: [{ refId: "A", expr: '{namespace="mesh",container="istio-proxy"} |= "inbound"', queryType: "range" }], range: { from: "now-15m", to: "now" } } });
const prom = (expr) => `http://localhost:9090/graph?g0.expr=${encodeURIComponent(expr)}&g0.tab=0&g0.range_input=15m`;

// Kiali só liga os cadeados de mTLS pelo menu Display (não pela URL)
const security = async (p) => {
  await p.getByRole("button", { name: "Display" }).click();
  await p.getByLabel("Security").check();
  await p.getByRole("button", { name: "Display" }).click();
  await p.waitForTimeout(3000);
};

const shots = [
  { n: "01-kiali-seguranca", url: kiali(""), wait: 8000, act: security },
  { n: "02-kiali-distribuicao", url: kiali("edges=trafficDistribution"), wait: 9000 },
  { n: "03-kiali-latencia", url: kiali("edges=responseTime,rt95"), wait: 9000 },
  { n: "04-kiali-workloads", url: `${K}/workloads?namespaces=mesh`, wait: 6000 },
  { n: "05-kiali-config-istio", url: `${K}/istio?namespaces=mesh`, wait: 6000 },
  { n: "06-grafana-servico", url: `${G}/d/dg4avusfw8z5sa/istio-service-dashboard?orgId=1&from=now-15m&to=now&var-service=frontend.mesh.svc.cluster.local&kiosk`, wait: 12000 },
  { n: "07-grafana-workload", url: `${G}/d/dg4avusrca874f/istio-workload-dashboard?orgId=1&from=now-15m&to=now&var-namespace=mesh&var-workload=frontend&kiosk`, wait: 12000 },
  { n: "08-grafana-malha", url: `${G}/d/1a9a8ea49444aae205c7737573e894f9/istio-mesh-dashboard?orgId=1&from=now-15m&to=now&kiosk`, wait: 12000 },
  { n: "09-grafana-plano-controle", url: `${G}/d/1813f692a8e4ac77155348d4c7d2fba8/istio-control-plane-dashboard?orgId=1&from=now-15m&to=now&kiosk`, wait: 12000 },
  { n: "10-loki-access-log", url: `${G}/explore?schemaVersion=1&orgId=1&panes=${encodeURIComponent(loki)}`, wait: 10000 },
  { n: "11-prometheus-requisicoes", url: prom('sum by (destination_workload)(rate(istio_requests_total{reporter="destination",destination_workload_namespace="mesh"}[1m]))'), wait: 6000 },
  { n: "12-prometheus-p95", url: prom('histogram_quantile(0.95, sum by (le,destination_workload)(rate(istio_request_duration_milliseconds_bucket{reporter="destination",destination_workload_namespace="mesh"}[2m])))'), wait: 6000 },
  { n: "13-jaeger-busca", url: "http://localhost:16686/jaeger/search?service=frontend.mesh&lookback=15m&limit=20", wait: 8000 },
  { n: "14-jaeger-trace", url: "about:blank", wait: 0,
    act: async (p) => { // abre o trace mais recente com mais spans (cadeia completa)
      const r = await (await fetch("http://localhost:16686/jaeger/api/traces?service=frontend.mesh&lookback=15m&limit=20")).json();
      const t = r.data.sort((a, b) => b.spans.length - a.spans.length)[0];
      await p.goto(`http://localhost:16686/jaeger/trace/${t.traceID}`);
      await p.waitForTimeout(6000);
    } },
];

mkdirSync("../evidencias", { recursive: true });
const want = process.argv.slice(2);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
for (const s of shots.filter((s) => !want.length || want.some((w) => s.n.includes(w)))) {
  try {
    await page.goto(s.url, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(s.wait);
    if (s.act) await s.act(page);
    await page.screenshot({ path: `../evidencias/${s.n}.png` });
    console.log("ok  ", s.n);
  } catch (e) {
    console.log("ERRO", s.n, String(e).split("\n")[0]);
  }
}
await browser.close();
