# frontend -> catalog (v1|v2) -> inventory. __IMG__ é trocado pela imagem do ACR.
apiVersion: v1
kind: ServiceAccount
metadata: {name: frontend}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: catalog}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: inventory}
---
apiVersion: v1
kind: Service
metadata: {name: frontend, labels: {app: frontend}}
spec: {selector: {app: frontend}, ports: [{name: http, port: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: catalog, labels: {app: catalog}}
spec: {selector: {app: catalog}, ports: [{name: http, port: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: inventory, labels: {app: inventory}}
spec: {selector: {app: inventory}, ports: [{name: http, port: 8080}]}
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
      serviceAccountName: frontend
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: frontend}, {name: VERSION, value: v1}, {name: UPSTREAM, value: "http://catalog:8080"}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
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
      serviceAccountName: catalog
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: catalog}, {name: VERSION, value: v1}, {name: UPSTREAM, value: "http://inventory:8080"}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
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
      serviceAccountName: catalog
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: catalog}, {name: VERSION, value: v2}, {name: UPSTREAM, value: "http://inventory:8080"}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
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
      serviceAccountName: inventory
      nodeSelector: {role: app}
      containers:
      - name: app
        image: __IMG__
        imagePullPolicy: Always
        env: [{name: NAME, value: inventory}, {name: VERSION, value: v1}]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 50m, memory: 32Mi}}
