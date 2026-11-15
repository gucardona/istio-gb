// Lista dashboards e fontes de dados do Grafana (via port-forward em localhost:3000).
const j = async (p) => (await fetch(`http://localhost:3000${p}`)).json();
for (const d of await j("/api/search?type=dash-db")) console.log("dash", d.uid, d.title);
for (const d of await j("/api/datasources")) console.log("ds", d.uid, d.name, d.type);
