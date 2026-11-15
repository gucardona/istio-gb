# Canário: ${W1}% das requisições para catalog v1 e ${W2}% para v2 (sem tocar no código).
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata: {name: catalog}
spec:
  hosts: [catalog]
  http:
  - route:
    - {destination: {host: catalog, subset: v1}, weight: ${W1}}
    - {destination: {host: catalog, subset: v2}, weight: ${W2}}
