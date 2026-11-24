# CKAD Mock Exam 4 – Solutions

> Only read after the 120 minutes are up!

### 1 – Image with build arguments
```dockerfile
FROM alpine:3.20
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
CMD ["sh", "-c", "echo \"version $APP_VERSION\"; sleep 3600"]
```
```bash
docker build --build-arg APP_VERSION=3.1 -t c4-app:3.1 /tmp/c4
kind load docker-image c4-app:3.1 --name ckad
kubectl -n c4-app run c4-app --image=c4-app:3.1 --image-pull-policy=IfNotPresent
kubectl -n c4-app logs c4-app        # version 3.1
```
`ARG` only exists at build time – copying it into `ENV` makes it available at runtime.

### 2 – Wait for dependencies
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: c4-frontend, namespace: c4-app}
spec:
  selector: {matchLabels: {app: c4-frontend}}
  template:
    metadata: {labels: {app: c4-frontend}}
    spec:
      initContainers:
        - name: wait-backend
          image: busybox:1.36
          command: ["sh", "-c", "until wget -qO- -T 2 http://c4-backend; do echo waiting; sleep 2; done"]
      containers: [{name: web, image: "nginx:1.27"}]
```
```bash
kubectl -n c4-app create deploy c4-backend --image=nginx:1.27
kubectl -n c4-app expose deploy c4-backend --port=80
```

### 3 – Suspended CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata: {name: c4-backup, namespace: c4-app}
spec:
  schedule: "15 1 * * *"
  suspend: true
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers: [{name: c, image: "busybox:1.36", command: ["echo", "backup"]}]
```
```bash
kubectl -n c4-app create job c4-backup-manual --from=cronjob/c4-backup
```
A manual run works even while the CronJob is suspended.

### 4 – Promote a canary
```bash
kubectl -n c4-app set image deploy/web-stable nginx=nginx:1.27
kubectl -n c4-app rollout status deploy/web-stable
kubectl -n c4-app delete deploy web-canary
```
Updating stable **first** keeps endpoints available the whole time (rolling update + canary pod).

### 5 – Batched changes
```bash
kubectl -n c4-app rollout pause deploy/api
kubectl -n c4-app set image deploy/api nginx=nginx:1.27-alpine
kubectl -n c4-app set env deploy/api LOG_LEVEL=debug
kubectl -n c4-app set resources deploy/api --limits=memory=128Mi
kubectl -n c4-app rollout resume deploy/api
```
(Editing all three fields in a single `kubectl edit` works too.)

### 6 – Helm template
```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update
helm template c4-render podinfo/podinfo --set replicaCount=2 > /tmp/c4-rendered.yaml
kubectl apply -n c4-helm -f /tmp/c4-rendered.yaml
```

### 7 – Exec and TCP probes
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c4-redis, namespace: c4-app}
spec:
  containers:
    - name: redis
      image: redis:7
      readinessProbe:
        exec: {command: ["redis-cli", "ping"]}
        periodSeconds: 5
      livenessProbe:
        tcpSocket: {port: 6379}
        periodSeconds: 10
```

### 8 – Events
```bash
kubectl -n c4-broken get events --field-selector type=Warning \
  -o jsonpath='{range .items[*]}{.involvedObject.name}{"\n"}{end}' | sort -u > /tmp/c4-warning-pods.txt
```
→ `crash-loop`, `pull-fail`, `unschedulable`.

### 9 – Debug a copy
```bash
kubectl -n c4-app debug app-locked --copy-to=app-locked-debug --container=app -- sleep 3600
kubectl -n c4-app exec app-locked-debug -c app -- cat /config/app.conf > /tmp/c4-appconf.txt
```
`kubectl debug --copy-to ... -- <cmd>` replaces the command of the selected container in the copy.

### 10 – Secret from files
```bash
kubectl -n c4-app create secret generic c4-creds --from-file=/tmp/c4/username --from-file=/tmp/c4/password
```
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c4-creds-user, namespace: c4-app}
spec:
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      env:
        - {name: USERNAME, valueFrom: {secretKeyRef: {name: c4-creds, key: username}}}
        - {name: PASSWORD, valueFrom: {secretKeyRef: {name: c4-creds, key: password}}}
```

### 11 – fsGroup
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c4-shared, namespace: c4-app}
spec:
  securityContext: {runAsUser: 1001, fsGroup: 4000}
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext: {readOnlyRootFilesystem: true}
      volumeMounts: [{name: work, mountPath: /work}]
  volumes: [{name: work, emptyDir: {}}]
```

### 12 – ServiceAccount
```bash
kubectl -n c4-app create sa c4-watcher
kubectl -n c4-app patch sa c4-watcher -p '{"automountServiceAccountToken":false}'
kubectl -n c4-app create role pod-watcher --verb=watch,list --resource=pods
kubectl -n c4-app create rolebinding c4-watcher --role=pod-watcher --serviceaccount=c4-app:c4-watcher
```
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c4-watcher, namespace: c4-app}
spec:
  serviceAccountName: c4-watcher
  automountServiceAccountToken: true        # the pod setting overrides the ServiceAccount
  containers: [{name: c, image: "busybox:1.36", command: ["sleep", "3600"]}]
```

### 13 – QoS
Guaranteed = every container has requests **equal to** limits for CPU and memory.
```bash
kubectl -n c4-app set resources deploy critical --requests=cpu=50m,memory=32Mi --limits=cpu=50m,memory=32Mi
```

### 14 – Custom resource
```bash
kubectl explain feature.spec --recursive
```
```yaml
apiVersion: flags.ckad.io/v1
kind: Feature
metadata: {name: dark-mode, namespace: c4-app}
spec:
  enabled: true
  rollout: {percentage: 25}
```

### 15 – Service troubleshooting
1. The service uses `targetPort: http`, but the container port is named `web`.
2. The NetworkPolicy `inventory-lock` blocks all ingress to the inventory pods.
```bash
kubectl -n c4-net patch svc inventory --type=json -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":"web"}]'
```
Then allow the tester – task 16's policy does exactly that.

### 16 – NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: inventory-access, namespace: c4-net}
spec:
  podSelector: {matchLabels: {app: inventory}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector: {matchLabels: {purpose: monitoring}}     # OR
        - podSelector: {matchLabels: {role: tester}}
```
Policies are additive – `inventory-lock` can stay; the allow rule wins.

### 17 – Ingress
```bash
kubectl -n c4-app create ingress c4-paths --class=traefik \
  --rule="c4.ckad.lab/*=web:80" --rule="c4.ckad.lab/healthz=api:80"
kubectl -n c4-app get ingress c4-paths -o jsonpath='{.spec.rules[0].http.paths[*].pathType}'   # Prefix Exact
```
