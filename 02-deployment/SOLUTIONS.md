# Domain 2 – Solutions

> Only look after your own attempt!

## 2.1 – Rolling update
```bash
kubectl -n deploy create deploy shop --image=nginx:1.26 --replicas=6 --dry-run=client -o yaml > /tmp/shop.yaml
```
```yaml
spec:
  replicas: 6
  minReadySeconds: 5
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 2
```
```bash
kubectl apply -f /tmp/shop.yaml
kubectl -n deploy set image deploy/shop nginx=nginx:1.27
kubectl -n deploy rollout status deploy/shop
kubectl -n deploy rollout pause deploy/shop
kubectl -n deploy set image deploy/shop nginx=nginx:1.27-alpine
kubectl -n deploy set env deploy/shop MODE=prod
kubectl -n deploy rollout resume deploy/shop
kubectl -n deploy rollout history deploy/shop
```
While paused, changes accumulate – resuming triggers **one** rollout (one new ReplicaSet) for both changes.

## 2.2 – Rollback
```bash
kubectl -n deploy set image deploy/shop nginx=nginx:1.27-broken
kubectl -n deploy rollout history deploy/shop
kubectl -n deploy rollout history deploy/shop --revision=3      # check the image
kubectl -n deploy rollout undo deploy/shop --to-revision=3
kubectl -n deploy patch deploy shop -p '{"spec":{"progressDeadlineSeconds":60}}'
```
After the deadline, the Deployment condition `Progressing` becomes `False` with reason
`ProgressDeadlineExceeded` – Kubernetes does **not** roll back automatically.

## 2.3 – Recreate strategy
```bash
kubectl -n deploy create deploy legacy --image=nginx:1.27 --replicas=2
kubectl -n deploy patch deploy legacy -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
kubectl -n deploy set image deploy/legacy nginx=nginx:1.27-alpine && kubectl -n deploy get pods -w
```
All old pods are terminated before new ones start → short downtime, but never two versions at once.

## 2.4 – Blue/green
Generate a skeleton with `kubectl create deploy ... --dry-run=client -o yaml` and adjust the labels:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: app-blue, namespace: deploy}
spec:
  replicas: 3
  selector: {matchLabels: {app: web, version: blue}}
  template:
    metadata: {labels: {app: web, version: blue}}
    spec:
      containers: [{name: nginx, image: "nginx:1.26"}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: app-green, namespace: deploy}
spec:
  replicas: 3
  selector: {matchLabels: {app: web, version: green}}
  template:
    metadata: {labels: {app: web, version: green}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27"}]
---
apiVersion: v1
kind: Service
metadata: {name: web, namespace: deploy}
spec:
  selector: {app: web, version: blue}
  ports: [{port: 80}]
```
```bash
kubectl -n deploy patch svc web -p '{"spec":{"selector":{"app":"web","version":"green"}}}'
kubectl -n deploy get endpointslices -l kubernetes.io/service-name=web -o wide
```
Rollback = patch the selector back to `blue` (the blue pods are still running).

## 2.5 – Canary
```yaml
apiVersion: v1
kind: Service
metadata: {name: canary, namespace: deploy}
spec:
  selector: {app: frontend}
  ports: [{port: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend-stable, namespace: deploy}
spec:
  replicas: 4
  selector: {matchLabels: {app: frontend, track: stable}}
  template:
    metadata: {labels: {app: frontend, track: stable}}
    spec:
      containers: [{name: nginx, image: "nginx:1.26"}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend-canary, namespace: deploy}
spec:
  replicas: 1
  selector: {matchLabels: {app: frontend, track: canary}}
  template:
    metadata: {labels: {app: frontend, track: canary}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27"}]
```
4 + 1 pods behind one service = ~20 % canary. Promote:
```bash
kubectl -n deploy set image deploy/frontend-stable nginx=nginx:1.27
kubectl -n deploy scale deploy frontend-canary --replicas=0      # or delete it
```
The split is only approximate (kube-proxy load-balances per connection). For exact percentages
use Gateway API weights or a service mesh.

## 2.6 – Helm basics
```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update
helm search repo podinfo/podinfo --versions | head
helm install blog podinfo/podinfo -n helm-apps --create-namespace --set replicaCount=2 --version <older-version-from-the-list>
helm upgrade blog podinfo/podinfo -n helm-apps --reuse-values
helm rollback blog 1 -n helm-apps
helm history blog -n helm-apps
helm status blog -n helm-apps
```

## 2.7 – Helm values & templates
```bash
helm show values podinfo/podinfo > /tmp/podinfo-defaults.yaml
cat > /tmp/podinfo-prod.yaml <<'EOF'
replicaCount: 3
resources:
  requests:
    cpu: 50m
ui:
  message: "production"
EOF
helm template prod podinfo/podinfo -n helm-apps -f /tmp/podinfo-prod.yaml > /tmp/podinfo-rendered.yaml
helm install prod podinfo/podinfo -n helm-apps -f /tmp/podinfo-prod.yaml
helm uninstall blog -n helm-apps --keep-history
helm list -n helm-apps --all          # blog shows as "uninstalled"
```
Precedence: chart defaults < `-f` files (in order) < `--set`.

## 2.8 – Kustomize overlays
```bash
mkdir -p /tmp/kust/{base,overlays/dev,overlays/prod} && cd /tmp/kust
kubectl create deploy api --image=nginx:1.27 --dry-run=client -o yaml > base/deployment.yaml
kubectl create svc clusterip api --tcp=80:80 --dry-run=client -o yaml > base/service.yaml
printf 'resources: [deployment.yaml, service.yaml]\n' > base/kustomization.yaml
cat > overlays/dev/kustomization.yaml <<'EOF'
resources: [../../base]
namespace: kdev
nameSuffix: -dev
labels:
  - pairs: {env: dev}
EOF
cat > overlays/prod/kustomization.yaml <<'EOF'
resources: [../../base]
namespace: kprod
replicas:
  - {name: api, count: 3}
images:
  - {name: nginx, newTag: 1.27-alpine}
labels:
  - pairs: {env: prod}
configMapGenerator:
  - name: api-env
    literals: [LOG=warn]
EOF
kubectl create ns kdev; kubectl create ns kprod
kubectl apply -k overlays/dev && kubectl apply -k overlays/prod
```
JSON 6902 patch instead of `replicas:`:
```yaml
patches:
  - target: {group: apps, version: v1, kind: Deployment, name: api}
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```
`kubectl kustomize <dir>` shows the result without applying. kubectl's built-in Kustomize may lag
behind the standalone `kustomize` binary.
