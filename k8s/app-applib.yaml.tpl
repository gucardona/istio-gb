# Modo B: as mesmas funções do Istio feitas DENTRO da aplicação (mTLS, métricas, autorização por CN).
# Retry/timeout/circuit breaker e a falha injetada entram por `kubectl set env` em cada cenário.
apiVersion: v1
kind: Service
metadata: {name: frontend, labels: {app: frontend}}
spec: {selector: {app: frontend}, ports: [{name: https, port: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: catalog, labels: {app: catalog}}
spec: {selector: {app: catalog}, ports: [{name: https, port: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: inventory, labels: {app: inventory}}
spec: {selector: {app: inventory}, ports: [{name: https, port: 8080}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector: {matchLabels: {app: frontend, version: v1}}
  template:
    metadata: {labels: {app: frontend, version: v1}}
    spec:
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: frontend}, {name: VERSION, value: v1}, {name: UPSTREAM, value: "https://catalog:8080"}, {name: TLS_DIR, value: /tls}, {name: METRICS, value: "1"}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
        volumeMounts: [{name: tls, mountPath: /tls, readOnly: true}]
      volumes: [{name: tls, secret: {secretName: tls-frontend}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: catalog-v1}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector: {matchLabels: {app: catalog, version: v1}}
  template:
    metadata: {labels: {app: catalog, version: v1}}
    spec:
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: catalog}, {name: VERSION, value: v1}, {name: UPSTREAM, value: "https://inventory:8080"}, {name: TLS_DIR, value: /tls}, {name: METRICS, value: "1"}, {name: ALLOWED_CLIENTS, value: frontend}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
        volumeMounts: [{name: tls, mountPath: /tls, readOnly: true}]
      volumes: [{name: tls, secret: {secretName: tls-catalog}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: catalog-v2}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector: {matchLabels: {app: catalog, version: v2}}
  template:
    metadata: {labels: {app: catalog, version: v2}}
    spec:
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: catalog}, {name: VERSION, value: v2}, {name: UPSTREAM, value: "https://inventory:8080"}, {name: TLS_DIR, value: /tls}, {name: METRICS, value: "1"}, {name: ALLOWED_CLIENTS, value: frontend}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
        volumeMounts: [{name: tls, mountPath: /tls, readOnly: true}]
      volumes: [{name: tls, secret: {secretName: tls-catalog}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: inventory}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector: {matchLabels: {app: inventory, version: v1}}
  template:
    metadata: {labels: {app: inventory, version: v1}}
    spec:
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: inventory}, {name: VERSION, value: v1}, {name: TLS_DIR, value: /tls}, {name: METRICS, value: "1"}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
        volumeMounts: [{name: tls, mountPath: /tls, readOnly: true}]
      volumes: [{name: tls, secret: {secretName: tls-inventory}}]
---
# Clientes de teste com o certificado "client" (CN=client), para fortio e curl falarem mTLS.
apiVersion: apps/v1
kind: Deployment
metadata: {name: load}
spec:
  replicas: 1
  selector: {matchLabels: {app: load}}
  template:
    metadata: {labels: {app: load}}
    spec:
      nodeSelector: {role: load}
      containers:
      - name: fortio
        image: fortio/fortio:1.69.5
        args: ["server", "-http-port", "8082", "-redirect-port", "disabled"]
        volumeMounts: [{name: tls, mountPath: /tls, readOnly: true}]
      volumes: [{name: tls, secret: {secretName: tls-client}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: curl}
spec:
  replicas: 1
  selector: {matchLabels: {app: curl}}
  template:
    metadata: {labels: {app: curl}}
    spec:
      nodeSelector: {role: load}
      containers:
      - name: curl
        image: curlimages/curl:8.10.1
        command: ["sleep", "infinity"]
        volumeMounts: [{name: tls, mountPath: /tls, readOnly: true}]
      volumes: [{name: tls, secret: {secretName: tls-client}}]
