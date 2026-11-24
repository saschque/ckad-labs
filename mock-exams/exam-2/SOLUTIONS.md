# CKAD Mock Exam 2 – Solutions

> Only read after the 120 minutes are up!

### 1 – Modify an image
```dockerfile
FROM alpine:3.20
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app \
 && mkdir /app && echo 'echo "api running as $(id -u)"; sleep 3600' > /app/run.sh && chown -R app:app /app
USER 10001
CMD ["sh", "/app/run.sh"]
```
```bash
docker build -t c2-api:2.0 /tmp/c2
docker save c2-api:2.0 -o /tmp/c2-api-2.0.tar
kind load docker-image c2-api:2.0 --name ckad
kubectl -n c2-app run c2-api --image=c2-api:2.0 --image-pull-policy=IfNotPresent
kubectl -n c2-app logs c2-api       # api running as 10001
```
Use the numeric UID in `USER` – then `runAsNonRoot: true` can verify it.

### 2 – Parallel Job
```yaml
apiVersion: batch/v1
kind: Job
metadata: {name: c2-render, namespace: c2-app}
spec:
  completions: 10
  parallelism: 5
  backoffLimit: 4
  ttlSecondsAfterFinished: 120
  template:
    spec:
      restartPolicy: Never
      containers: [{name: c, image: "busybox:1.36", command: ["sh", "-c", "echo rendering; sleep 3"]}]
```

### 3 – Volumes
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: c2-data, namespace: c2-app}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 100Mi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: c2-store, namespace: c2-app}
spec:
  selector: {matchLabels: {app: c2-store}}
  template:
    metadata: {labels: {app: c2-store}}
    spec:
      containers:
        - name: c
          image: busybox:1.36
          command: ["sleep", "3600"]
          volumeMounts:
            - {name: data, mountPath: /data}
            - {name: cache, mountPath: /cache}
      volumes:
        - {name: data, persistentVolumeClaim: {claimName: c2-data}}
        - {name: cache, emptyDir: {medium: Memory, sizeLimit: 16Mi}}
```

### 4 – Blue/green
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: checkout-green, namespace: c2-app}
spec:
  replicas: 2
  selector: {matchLabels: {app: checkout, color: green}}
  template:
    metadata: {labels: {app: checkout, color: green}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27"}]
```
```bash
kubectl -n c2-app rollout status deploy/checkout-green
kubectl -n c2-app patch svc checkout -p '{"spec":{"selector":{"app":"checkout","color":"green"}}}'
```

### 5 – Rollback
```bash
kubectl -n c2-app rollout history deploy/catalog
for r in 1 2 3 4; do kubectl -n c2-app rollout history deploy/catalog --revision=$r | grep Image; done
kubectl -n c2-app rollout undo deploy/catalog --to-revision=2      # nginx:1.26
```
A plain `rollout undo` would go back to revision 3 – which is broken too.

### 6 – Kustomize
```bash
mkdir -p /tmp/c2-kust/staging
cat > /tmp/c2-kust/staging/kustomization.yaml <<'EOF'
resources: [../base]
namespace: c2-staging
namePrefix: staging-
images:
  - {name: nginx, newTag: 1.27-alpine}
configMapGenerator:
  - name: web-config
    literals: [STAGE=staging]
EOF
kubectl apply -k /tmp/c2-kust/staging
```

### 7 – Startup probe
```bash
kubectl -n c2-app patch deploy legacy-app --type=strategic -p '
spec:
  template:
    spec:
      containers:
        - name: app
          startupProbe:
            httpGet: {path: /healthz, port: 8080}
            periodSeconds: 5
            failureThreshold: 12'
```
12 × 5 s = up to 60 s for the start; the liveness probe only starts after the startup probe succeeded.

### 8 – Resource monitoring
```bash
kubectl top pods -n c2-load --sort-by=memory --no-headers | head -1 | awk '{print $1}' > /tmp/c2-top-mem.txt
```

### 9 – Debug container
```bash
kubectl -n c2-app debug -it minimal --image=busybox:1.36 --target=app -- sh
cat /proc/1/cmdline; echo        # /pause
# from outside, non-interactively:
kubectl -n c2-app debug minimal --image=busybox:1.36 --target=app -- sleep 3600
kubectl -n c2-app exec minimal -c <debugger-name> -- cat /proc/1/cmdline > /tmp/c2-pid1.txt
```
The debugger name is shown in the output (`debugger-xxxxx`) and in `.spec.ephemeralContainers`.

### 10 – ConfigMap usage
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c2-env, namespace: c2-app}
spec:
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      envFrom: [{prefix: FLAG_, configMapRef: {name: c2-flags}}]
      volumeMounts: [{name: rules, mountPath: /etc/app/rules.json, subPath: rules.json}]
  volumes:
    - name: rules
      configMap: {name: c2-flags}
```

### 11 – Pod Security
```bash
kubectl label ns c2-secure pod-security.kubernetes.io/enforce=restricted
```
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c2-ok, namespace: c2-secure}
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
```

### 12 – Secrets
```bash
kubectl -n c2-app create secret generic c2-db --from-file=db.properties=/tmp/c2/db.properties
```
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c2-db-client, namespace: c2-app}
spec:
  containers:
    - {name: c, image: "busybox:1.36", command: ["sleep", "3600"], volumeMounts: [{name: db, mountPath: /etc/db}]}
  volumes:
    - name: db
      secret: {secretName: c2-db, defaultMode: 0400}
```

### 13 – LimitRange
```yaml
apiVersion: v1
kind: LimitRange
metadata: {name: defaults, namespace: c2-limits}
spec:
  limits:
    - type: Container
      defaultRequest: {cpu: 100m, memory: 64Mi}
      default: {cpu: 250m, memory: 128Mi}
      max: {memory: 512Mi}
```

### 14 – Extending Kubernetes
```bash
kubectl api-resources | grep -i widget      # widgets  wdg  toys.ckad.io/v1  false  Widget
printf 'scope=Cluster\nshortname=wdg\n' > /tmp/c2-widget.txt
kubectl apply -f - <<'EOF'
apiVersion: toys.ckad.io/v1
kind: Widget
metadata: {name: gizmo}
spec: {color: blue}
EOF
```
`NAMESPACED false` = cluster-scoped → no namespace in the metadata.

### 15 – Egress policy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: frontend-egress, namespace: c2-net}
spec:
  podSelector: {matchLabels: {app: frontend}}
  policyTypes: [Egress]
  egress:
    - to: [{podSelector: {matchLabels: {app: api}}}]
      ports: [{protocol: TCP, port: 8080}]
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
          podSelector: {matchLabels: {k8s-app: kube-dns}}
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
```

### 16 – NodePort
```bash
kubectl -n c2-net expose deploy api --name=api-public --type=NodePort --port=80 --target-port=8080
kubectl -n c2-net patch svc api-public --type=json -p='[{"op":"replace","path":"/spec/ports/0/nodePort","value":30222}]'
```

### 17 – TLS Ingress
```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=shop.c2.lab" -keyout /tmp/c2.key -out /tmp/c2.crt
kubectl -n c2-app create secret tls c2-tls --cert=/tmp/c2.crt --key=/tmp/c2.key
kubectl -n c2-app create ingress c2-shop --class=traefik --rule="shop.c2.lab/*=checkout:80,tls=c2-tls"
curl -sk --resolve shop.c2.lab:30443:127.0.0.1 https://shop.c2.lab:30443/ | head -3
```
