# Domain 1 – Solutions

> Only look after your own attempt!

## 1.1 – Build an image
```bash
mkdir -p /tmp/app && cd /tmp/app
echo '<h1>CKAD v1</h1>' > index.html
cat > Dockerfile <<'EOF'
FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
EOF
docker build -t ckad-web:1.0 .
kind load docker-image ckad-web:1.0 --name ckad
kubectl -n design run web-v1 --image=ckad-web:1.0 --image-pull-policy=Never --port=80
kubectl -n design port-forward pod/web-v1 8080:80 &
curl -s localhost:8080
```
`imagePullPolicy: Never` (or `IfNotPresent`) is needed, otherwise Kubernetes tries to pull
`docker.io/library/ckad-web:1.0` and fails. Podman: `podman build`, then
`podman save ckad-web:1.0 -o x.tar && kind load image-archive x.tar --name ckad`.

## 1.2 – Modify an image
```bash
cd /tmp/app
echo '<h1>CKAD v2</h1>' > index.html
cat > Dockerfile <<'EOF'
FROM nginxinc/nginx-unprivileged:1.27-alpine
LABEL org.opencontainers.image.version="2.0"
COPY --chown=nginx:nginx index.html /usr/share/nginx/html/index.html
EXPOSE 8080
EOF
docker build -t ckad-web:2.0 .
docker save ckad-web:2.0 -o /tmp/ckad-web-2.0.tar        # podman save --format oci-archive ...
kind load docker-image ckad-web:2.0 --name ckad
kubectl -n design run web-v2 --image=ckad-web:2.0 --image-pull-policy=Never --port=8080
kubectl -n design exec web-v2 -- id                      # uid=101(nginx)
docker inspect ckad-web:2.0 --format '{{json .Config.Labels}}'
```

## 1.3 – Multi-stage build
```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY main.go .
RUN go mod init goapp && CGO_ENABLED=0 go build -o /app main.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```
```bash
docker build -t goapp:1.0 /tmp/goapp
docker images | grep -E 'goapp|golang'      # ~ 8 MB vs. ~ 800 MB
kind load docker-image goapp:1.0 --name ckad
kubectl -n design run goapp --image=goapp:1.0 --image-pull-policy=Never --port=8080
```
Distroless images have no shell – debugging works with `kubectl debug` (see domain 3).

## 1.4 – Choose the right workload
| Requirement | Workload |
|-------------|----------|
| One pod per node | **DaemonSet** |
| Stable names + own volume | **StatefulSet** (+ headless service) |
| Scheduled | **CronJob** |
| Run to completion once | **Job** |
| Interchangeable replicas + rolling updates | **Deployment** |

```bash
kubectl -n design create deploy api --image=nginx:1.27 --replicas=3
kubectl -n design create job migrate --image=busybox:1.36 -- echo migrated
kubectl -n design create cronjob report --image=busybox:1.36 --schedule="0 23 * * *" -- date
```
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata: {name: log-agent, namespace: design}
spec:
  selector: {matchLabels: {app: log-agent}}
  template:
    metadata: {labels: {app: log-agent}}
    spec:
      containers: [{name: agent, image: "busybox:1.36", command: ["sleep", "infinity"]}]
---
apiVersion: v1
kind: Service
metadata: {name: db, namespace: design}
spec: {clusterIP: None, selector: {app: db}, ports: [{port: 80}]}
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: db, namespace: design}
spec:
  serviceName: db
  replicas: 2
  selector: {matchLabels: {app: db}}
  template:
    metadata: {labels: {app: db}}
    spec:
      containers:
        - {name: db, image: "busybox:1.36", command: ["sleep", "infinity"], volumeMounts: [{name: data, mountPath: /data}]}
  volumeClaimTemplates:
    - metadata: {name: data}
      spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 100Mi}}}
```
The DaemonSet runs on workers only because the control plane has a `NoSchedule` taint – exactly what was asked.

## 1.5 – Job tuning
```yaml
apiVersion: batch/v1
kind: Job
metadata: {name: batch, namespace: design}
spec:
  completions: 8
  parallelism: 4
  backoffLimit: 2
  activeDeadlineSeconds: 120
  ttlSecondsAfterFinished: 60
  template:
    spec:
      restartPolicy: Never
      containers:
        - {name: c, image: "busybox:1.36", command: ["sh", "-c", "echo processing; sleep 5"]}
```
`activeDeadlineSeconds` wins over `backoffLimit`: when the deadline is reached, all running pods
are terminated and the Job fails with `DeadlineExceeded`.

## 1.6 – Init container
```yaml
apiVersion: v1
kind: Pod
metadata: {name: waiter, namespace: design}
spec:
  initContainers:
    - name: wait-for-backend
      image: busybox:1.36
      command: ["sh", "-c", "until nslookup backend.design.svc.cluster.local; do echo waiting; sleep 2; done"]
  containers:
    - {name: web, image: "nginx:1.27"}
```
```bash
kubectl -n design get pod waiter -w          # Init:0/1
kubectl -n design create svc clusterip backend --tcp=80:80
```

## 1.7 – Sidecar
```yaml
apiVersion: v1
kind: Pod
metadata: {name: app-with-sidecar, namespace: design}
spec:
  initContainers:
    - name: log-forwarder
      image: busybox:1.36
      restartPolicy: Always            # native sidecar
      command: ["sh", "-c", "touch /var/log/app/app.log; tail -F /var/log/app/app.log"]
      volumeMounts: [{name: logs, mountPath: /var/log/app}]
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "while true; do echo \"$(date) request handled\" >> /var/log/app/app.log; sleep 3; done"]
      volumeMounts: [{name: logs, mountPath: /var/log/app}]
  volumes: [{name: logs, emptyDir: {}}]
```
`kubectl -n design logs app-with-sidecar -c log-forwarder -f`

## 1.8 – Adapter
```yaml
apiVersion: v1
kind: Pod
metadata: {name: metrics-pod, namespace: design}
spec:
  containers:
    - name: legacy
      image: busybox:1.36
      command: ["sh", "-c", "while true; do echo \"$(date -Iseconds) | cpu=$((RANDOM%100)) | mem=$((RANDOM%1024))\" >> /data/metrics.txt; sleep 5; done"]
      volumeMounts: [{name: data, mountPath: /data}]
    - name: adapter
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          while true; do
            line=$(tail -1 /data/metrics.txt 2>/dev/null)
            cpu=$(echo "$line" | sed -n 's/.*cpu=\([0-9]*\).*/\1/p')
            mem=$(echo "$line" | sed -n 's/.*mem=\([0-9]*\).*/\1/p')
            [ -n "$cpu" ] && echo "{\"cpu\":$cpu,\"mem\":$mem}" > /data/metrics.json
            sleep 5
          done
      volumeMounts: [{name: data, mountPath: /data}]
  volumes: [{name: data, emptyDir: {}}]
```
Patterns: **sidecar** extends the app (log shipping, proxies), **adapter** converts the app's
output into a standard format, **ambassador** proxies outgoing connections (e.g. to a database).

## 1.9 – Persistent and ephemeral volumes
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: uploads, namespace: design}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 200Mi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: uploader, namespace: design}
spec:
  replicas: 1
  strategy: {type: Recreate}           # RWO volume: avoid two pods at once during updates
  selector: {matchLabels: {app: uploader}}
  template:
    metadata: {labels: {app: uploader}}
    spec:
      containers:
        - name: c
          image: busybox:1.36
          command: ["sh", "-c", "date > /uploads/$(hostname).txt; sleep 3600"]
          volumeMounts:
            - {name: uploads, mountPath: /uploads}
            - {name: cache, mountPath: /tmp/cache}
      volumes:
        - {name: uploads, persistentVolumeClaim: {claimName: uploads}}
        - {name: cache, emptyDir: {sizeLimit: 64Mi}}
```
After deleting the pod, `/uploads` contains the file of the old **and** the new pod. The `emptyDir`
content is gone when the **pod** is deleted, but survives a **container** restart.
