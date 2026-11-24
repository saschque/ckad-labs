# Domain 3 – Solutions

> Only look after your own attempt!

## 3.1 – API deprecations
```bash
kubectl apply --dry-run=server -f scenarios/deprecated.yaml
# no matches for kind "Ingress" in version "extensions/v1beta1" ...
kubectl api-resources | grep -E 'ingresses|poddisruptionbudgets|horizontalpodautoscalers|cronjobs'
kubectl explain ingress.spec.rules.http.paths.backend
```
| Kind | Old | Current | Shape changes |
|------|-----|---------|---------------|
| Ingress | `extensions/v1beta1` | `networking.k8s.io/v1` | `backend.service.name/port.number`, `pathType` required |
| PodDisruptionBudget | `policy/v1beta1` | `policy/v1` | – |
| HorizontalPodAutoscaler | `autoscaling/v2beta2` | `autoscaling/v2` | – |
| CronJob | `batch/v1beta1` | `batch/v1` | – |

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: legacy-ingress, namespace: maint}
spec:
  rules:
    - host: legacy.ckad.lab
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: {name: legacy, port: {number: 80}}
```
(PDB, HPA, CronJob: only change `apiVersion`.)
```bash
kubectl -n maint create deploy legacy --image=nginx:1.27
kubectl -n maint expose deploy legacy --port=80
kubectl apply -f /tmp/converted.yaml
```
Which versions the cluster serves: `kubectl api-versions`, `kubectl api-resources`. To find
deprecated APIs in manifests: the `kubectl convert` plugin, tools like `pluto` or `kubent`, and the
**Deprecated API Migration Guide** on kubernetes.io. The API server also returns a warning
(`Warning: ... is deprecated in v1.x+, unavailable in v1.y+`) when you use a deprecated version.

## 3.2 – Probes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: probed, namespace: maint}
spec:
  replicas: 2
  selector: {matchLabels: {app: probed}}
  template:
    metadata: {labels: {app: probed}}
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          startupProbe:
            httpGet: {path: /, port: 80}
            periodSeconds: 2
            failureThreshold: 10
          readinessProbe:
            httpGet: {path: /, port: 80}
            periodSeconds: 5
            successThreshold: 1
          livenessProbe:
            exec:
              command: ["test", "-f", "/usr/share/nginx/html/index.html"]
            periodSeconds: 10
            failureThreshold: 3
```
```bash
P=$(kubectl -n maint get pods -l app=probed -o jsonpath='{.items[0].metadata.name}')
kubectl -n maint exec $P -- rm /usr/share/nginx/html/index.html
kubectl -n maint get pods -w        # readiness fails first (403), after ~30 s liveness restarts the container
```
After the restart, `index.html` is back (it comes from the image) – the container is healthy again.

## 3.3 – Fix probe timing
1. The liveness probe starts immediately and fails twice after ~10 s → restart loop before the
   app ever finishes its 25 s warm-up.
2. The readiness probe checks `/ready`, which doesn't exist → never Ready.
```bash
kubectl -n debug patch deploy slow-start --type=strategic -p '
spec:
  template:
    spec:
      containers:
        - name: app
          startupProbe:
            httpGet: {path: /health, port: 8080}
            periodSeconds: 5
            failureThreshold: 12
          readinessProbe:
            httpGet: {path: /health, port: 8080}'
```
A `startupProbe` blocks liveness and readiness until it succeeds – the cleanest fix for slow starts.
(`initialDelaySeconds: 30` on the liveness probe also works but delays failure detection.)

## 3.4 – Built-in monitoring
```bash
kubectl top pods -A --sort-by=memory
kubectl top pods -n kube-system --sort-by=cpu --no-headers | head -1 | awk '{print $1}' > /tmp/top-system-pod.txt
kubectl -n debug get events --sort-by=.lastTimestamp
kubectl -n debug get events --field-selector type=Warning
kubectl -n debug get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount --no-headers > /tmp/restarts.txt
```

## 3.5 – Container logs
```yaml
apiVersion: v1
kind: Pod
metadata: {name: talker, namespace: maint}
spec:
  containers:
    - name: a
      image: busybox:1.36
      command: ["sh", "-c", "i=0; while true; do i=$((i+1)); echo \"A $i\"; sleep 1; done"]
    - name: b
      image: busybox:1.36
      command: ["sh", "-c", "i=0; while true; do i=$((i+1)); echo \"B $i\" >&2; sleep 2; done"]
```
```bash
kubectl -n maint logs talker -c b --tail=5 --timestamps
kubectl -n maint logs talker --all-containers --prefix
kubectl -n maint logs -l app=probed -f --prefix --max-log-requests=10
```
`kubectl logs` shows stdout **and** stderr – you can't separate them with kubectl.

## 3.6 – Ephemeral debug containers
```bash
kubectl -n debug exec distroless -- sh                     # executable file not found
kubectl -n debug debug -it distroless --image=busybox:1.36 --target=app -- sh
ps aux                                                     # shows /pause (PID 1 of the target container)
kubectl -n debug debug distroless -it --copy-to=distroless-copy --set-image=app=busybox:1.36 -- sleep 3600
kubectl debug node/ckad-worker -it --image=busybox:1.36 -- cat /host/etc/hostname
```
- `--target` shares the process namespace with that container (needs runtime support).
- `--copy-to` creates a new pod – the original stays untouched.
- Node debugging mounts the node's root filesystem at `/host`. Clean up the `node-debugger-*` pod afterwards.

## 3.7 – Debugging broken workloads
| Deployment | Symptom | Cause | Fix |
|------------|---------|-------|-----|
| d1-api | `CrashLoopBackOff`, logs: `ERROR: /config/settings.ini missing` | ConfigMap mounted at `/etc/config`, app reads `/config` | Change `mountPath` to `/config` |
| d2-web | `OOMKilled` / `CrashLoopBackOff` (exit 137) | Memory limit 4Mi is far too low for nginx | Raise the limit, e.g. 64Mi |
| d3-worker | `CreateContainerConfigError`, event: `secret "d3-queue" not found` | Referenced Secret is missing | Create the Secret with key `host` |

```bash
kubectl -n debug patch deploy d1-api --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/volumeMounts/0/mountPath","value":"/config"}]'
kubectl -n debug set resources deploy d2-web --limits=memory=64Mi
kubectl -n debug create secret generic d3-queue --from-literal=host=queue.debug.svc
cat > /tmp/debug-causes.txt <<'EOF'
d1-api: configmap mounted at /etc/config instead of /config
d2-web: memory limit 4Mi too low (OOMKilled)
d3-worker: secret d3-queue missing
EOF
```

## 3.8 – Port-forward and exec
```bash
kubectl -n maint expose deploy probed --port=80
kubectl -n maint port-forward svc/probed 9090:80 &
curl -s localhost:9090 | head -4
kubectl -n maint exec deploy/probed -- nginx -T | head -20
```
