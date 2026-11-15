// Capturas A × B × C: histogramas do fortio (UI local em :8090 sobre results/fortio-ui) e CPU/RAM por namespace no Prometheus.
// Uso: fortio server -http-port 8090 -data-dir results/fortio-ui  &&  node shots-cmp.mjs [range, ex. 12m]
import { chromium } from "playwright";
const range = process.argv[2] || "12m";
const prom = (expr) => `http://localhost:9090/graph?g0.expr=${encodeURIComponent(expr)}&g0.tab=0&g0.range_input=${range}`;
const NS = 'namespace=~"plain|applib|mesh",container!="",container!="POD"';
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1440, height: 900 } });

for (const [n, files] of [["17-fortio-500rps-32con", ["q500_c32_plain.json", "q500_c32_applib.json", "q500_c32_mesh.json"]],
                          ["18-fortio-50rps-1con", ["q50_c1_plain.json", "q50_c1_applib.json", "q50_c1_mesh.json"]]]) {
  await p.goto("http://localhost:8090/fortio/browse");
  await p.selectOption("#files", files);
  await p.waitForTimeout(3000);
  await p.screenshot({ path: `../evidencias/${n}.png`, fullPage: false });
  console.log("ok  ", n);
}
for (const [n, expr] of [["19-prometheus-cpu-por-modo", `sum by (namespace)(rate(container_cpu_usage_seconds_total{${NS}}[1m]))`],
                         ["20-prometheus-memoria-por-modo", `sum by (namespace)(container_memory_working_set_bytes{${NS}}) / 1024 / 1024`]]) {
  await p.goto(prom(expr));
  await p.waitForTimeout(6000);
  await p.screenshot({ path: `../evidencias/${n}.png` });
  console.log("ok  ", n);
}
await b.close();
