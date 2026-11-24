# CKAD Mock Exam 1 – Solutions

> Only read after the 120 minutes are up!

### 1 – Build an image
```bash
docker build -t c1-app:1.0 /tmp/c1
kind load docker-image c1-app:1.0 --name ckad
kubectl -n c1-app run c1-app --image=c1-app:1.0 --image-pull-policy=IfNotPresent --port=8080
```
With a non-`latest` tag, the default pull policy is already `IfNotPresent`; with `:latest` it
would be `Always` and fail.

### 2 – Multi-container pod
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c1-web, namespace: c1-app}
spec:
  initContainers:
    - name: fetch
      image: busybox:1.36
      command: ["sh", "-c", "echo '<h1>c1</h1>' > /html/index.html"]
      volumeMounts: [{name: html, mountPath: /html}]
    - name: access-log
      image: busybox:1.36
      restartPolicy: Always
      command: ["sh", "-c", "touch /var/log/nginx/access.log; tail -F /var/log/nginx/access.log"]
      volumeMounts: [{name: logs, mountPath: /var/log/nginx}]
  containers:
    - name: web
      image: nginx:1.27
      volumeMounts:
        - {name: html, mountPath: /usr/share/nginx/html}
        - {name: logs, mountPath: /var/log/nginx}
  volumes:
    - {name: html, emptyDir: {}}
    - {name: logs, emptyDir: {}}
```

### 3 – CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata: {name: c1-cleanup, namespace: c1-app}
spec:
  schedule: "*/10 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      activeDeadlineSeconds: 30
      template:
        spec:
          restartPolicy: OnFailure
          containers: [{name: c, image: "busybox:1.36", command: ["echo", "cleanup"]}]
```

### 4 – Rolling update
```bash
kubectl -n c1-app patch deploy api -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":"25%","maxUnavailable":0}}}}'
kubectl -n c1-app set image deploy/api nginx=nginx:1.27
kubectl -n c1-app rollout status deploy/api
```

### 5 – Canary
3 old pods + 1 new pod = 25 %.
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: shop-v2, namespace: c1-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: shop, version: v2}}
  template:
    metadata: {labels: {app: shop, version: v2}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27"}]
```

### 6 – Helm
```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update
helm install c1-podinfo podinfo/podinfo -n c1-helm --set replicaCount=2 --set ui.message=c1
helm upgrade c1-podinfo podinfo/podinfo -n c1-helm --reuse-values --set replicaCount=3
```

### 7 – API deprecation
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: api-pdb, namespace: c1-app}
spec:
  minAvailable: 1
  selector: {matchLabels: {app: api}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: legacy, namespace: c1-app}
spec:
  rules:
    - host: legacy.c1.lab
      http:
        paths:
          - path: /
            pathType: Prefix
            backend: {service: {name: api, port: {number: 80}}}
```

### 8 – Probes
```bash
kubectl -n c1-app patch deploy api --type=strategic -p '
spec:
  template:
    spec:
      containers:
        - name: nginx
          readinessProbe:
            httpGet: {path: /, port: 80}
            periodSeconds: 5
          livenessProbe:
            tcpSocket: {port: 80}
            periodSeconds: 10
            initialDelaySeconds: 5'
```

### 9 – Debugging
```bash
kubectl -n c1-debug logs worker --previous | grep ERROR > /tmp/c1-error.txt    # or without --previous
kubectl -n c1-debug get pod worker -o yaml > /tmp/worker.yaml
# add: env: [{name: QUEUE_URL, value: "amqp://queue:5672"}]
kubectl -n c1-debug replace --force -f /tmp/worker.yaml
```
Most pod fields are immutable → `replace --force` (delete + create) is the fastest way.

### 10 – Configuration
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c1-config, namespace: c1-app}
spec:
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      envFrom: [{configMapRef: {name: c1-settings}}]
      volumeMounts: [{name: secret, mountPath: /etc/secret, readOnly: true}]
  volumes:
    - name: secret
      secret:
        secretName: c1-secret
        items: [{key: token, path: token}]
```

### 11 – SecurityContext
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c1-secure, namespace: c1-app}
spec:
  securityContext: {runAsUser: 2000}
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: {drop: ["ALL"]}
```

### 12 – ServiceAccount
```bash
kubectl -n c1-app create sa c1-bot
kubectl -n c1-app create role c1-bot --verb=get,list --resource=configmaps
kubectl -n c1-app create rolebinding c1-bot --role=c1-bot --serviceaccount=c1-app:c1-bot
kubectl -n c1-app set serviceaccount deploy api c1-bot
```

### 13 – Resources under a quota
The quota covers requests **and** limits for CPU and memory → every container must set all four.
2 pods must fit into `requests.cpu: 500m`, `requests.memory: 256Mi`, `limits.cpu: 1`, `limits.memory: 512Mi`.
```bash
kubectl -n c1-quota create deploy c1-fit --image=nginx:1.27 --replicas=2
kubectl -n c1-quota set resources deploy c1-fit --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi
kubectl -n c1-quota describe quota quota
```

### 14 – Custom resources
```bash
kubectl api-resources | grep -i database          # databases  db  data.ckad.io/v1alpha1
kubectl explain database.spec
```
```yaml
apiVersion: data.ckad.io/v1alpha1
kind: Database
metadata: {name: orders-db, namespace: c1-app}
spec: {engine: postgres, storageGB: 10}
```

### 15 – NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: db-policy, namespace: c1-net}
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
    - from: [{podSelector: {matchLabels: {role: api}}}]
      ports: [{protocol: TCP, port: 5432}]
```

### 16 – Service
Two problems: selector `app: catalogue` (pods: `app: catalog`) and `targetPort: 8080` (container: 9000).
```bash
kubectl -n c1-net patch svc catalog --type=json -p='[
  {"op":"replace","path":"/spec/selector/app","value":"catalog"},
  {"op":"replace","path":"/spec/ports/0/targetPort","value":9000}]'
kubectl -n c1-net exec client -- wget -qO- -T 3 catalog
```

### 17 – Ingress
```bash
kubectl -n c1-app create ingress c1-ingress --class=traefik \
  --rule="c1.ckad.lab/api*=api:80" --rule="c1.ckad.lab/shop*=shop:80"
```
