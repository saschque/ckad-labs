# CKAD Mock Exam 3 – Solutions

> Only read after the 120 minutes are up!

### 1 – Fix an image
Two bugs: the ENTRYPOINT points to `/usr/local/bin/tool` (the file is `tool.sh`) and the script is
not executable.
```dockerfile
FROM busybox:1.36
COPY --chmod=755 tool.sh /usr/local/bin/tool.sh
ENTRYPOINT ["/usr/local/bin/tool.sh"]
```
```bash
docker build -t c3-tool:1.0 /tmp/c3
kind load docker-image c3-tool:1.0 --name ckad
kubectl -n c3-app create job c3-tool --image=c3-tool:1.0
kubectl -n c3-app logs job/c3-tool      # tool finished
```
(`COPY --chmod` needs BuildKit; alternatively `RUN chmod +x ...` after the COPY.)

### 2 – Adapter pattern
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c3-metrics, namespace: c3-app}
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "i=0; while true; do i=$((i+1)); echo \"requests=$i\" > /data/raw.txt; sleep 3; done"]
      volumeMounts: [{name: data, mountPath: /data}]
    - name: adapter
      image: busybox:1.36
      command: ["sh", "-c", "while true; do n=$(cut -d= -f2 /data/raw.txt 2>/dev/null); [ -n \"$n\" ] && echo \"{\\\"requests\\\": $n}\" > /data/metrics.json; sleep 3; done"]
      volumeMounts: [{name: data, mountPath: /data}]
  volumes: [{name: data, emptyDir: {}}]
```

### 3 – StatefulSet
```yaml
apiVersion: v1
kind: Service
metadata: {name: c3-queue, namespace: c3-app}
spec: {clusterIP: None, selector: {app: c3-queue}, ports: [{port: 80}]}
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: c3-queue, namespace: c3-app}
spec:
  serviceName: c3-queue
  replicas: 3
  podManagementPolicy: Parallel
  selector: {matchLabels: {app: c3-queue}}
  template:
    metadata: {labels: {app: c3-queue}}
    spec:
      containers:
        - {name: q, image: "busybox:1.36", command: ["sleep", "infinity"], volumeMounts: [{name: data, mountPath: /var/queue}]}
  volumeClaimTemplates:
    - metadata: {name: data}
      spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 50Mi}}}
```

### 4 – Recreate strategy
```bash
kubectl -n c3-app patch deploy migrator -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
kubectl -n c3-app set image deploy/migrator m=busybox:1.37
```

### 5 – Helm versions
```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update
V=$(helm search repo podinfo/podinfo --versions -o json | jq -r '.[1].version')
echo "$V" > /tmp/c3-version.txt
helm install c3-pinned podinfo/podinfo -n c3-helm --version "$V"
```

### 6 – Kustomize JSON patch
```bash
mkdir -p /tmp/c3-kust/prod
cat > /tmp/c3-kust/prod/kustomization.yaml <<'EOF'
resources: [../base]
namespace: c3-prod
patches:
  - target: {group: apps, version: v1, kind: Deployment, name: api}
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env
        value: [{name: ENV, value: prod}]
      - op: replace
        path: /spec/replicas
        value: 2
EOF
kubectl apply -k /tmp/c3-kust/prod
```

### 7 – Deprecated APIs
```bash
kubectl api-versions | grep -E 'flowcontrol|discovery|storage'
kubectl apply --dry-run=server -f /tmp/c3/manifests.yaml 2>&1 | grep 'no matches'
printf 'FlowSchema\nEndpointSlice\nCSIStorageCapacity\n' > /tmp/c3-deprecated.txt
```
`flowcontrol.apiserver.k8s.io/v1beta2`, `discovery.k8s.io/v1beta1` and `storage.k8s.io/v1beta1`
have been removed; the current versions are `v1`.

### 8 – Logs
```bash
kubectl -n c3-logs logs gateway -c proxy | grep 'status=500' > /tmp/c3-500.log
```

### 9 – Fix a crashing app
```bash
kubectl -n c3-app describe pod -l app=cache | grep -A3 'Last State'     # OOMKilled, exit 137
kubectl -n c3-app set resources deploy cache --limits=memory=128Mi
```

### 10 – Projected token
```yaml
apiVersion: v1
kind: ServiceAccount
metadata: {name: c3-client, namespace: c3-app}
---
apiVersion: v1
kind: Pod
metadata: {name: c3-token, namespace: c3-app}
spec:
  serviceAccountName: c3-client
  automountServiceAccountToken: false
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      volumeMounts: [{name: vault, mountPath: /var/run/vault}]
  volumes:
    - name: vault
      projected:
        sources:
          - serviceAccountToken: {audience: vault, expirationSeconds: 3600, path: token}
```

### 11 – Capabilities
```yaml
apiVersion: v1
kind: Pod
metadata: {name: c3-net-tool, namespace: c3-app}
spec:
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext:
        privileged: false
        capabilities:
          drop: ["ALL"]
          add: ["NET_ADMIN", "NET_RAW"]
```

### 12 – Quota
```bash
kubectl -n c3-quota create quota c3-quota --hard=pods=3,services=2,requests.memory=300Mi
kubectl -n c3-quota create deploy c3-filler --image=nginx:1.27 --replicas=3
kubectl -n c3-quota set resources deploy c3-filler --requests=memory=100Mi
```
Without the request, the pods are rejected (`must specify requests.memory`) – a quota on a resource
forces every pod to declare it.

### 13 – RBAC check
```bash
SA=system:serviceaccount:c3-app:deployer
for c in "create deployments -n c3-app" "delete secrets -n c3-app" "list pods -n default"; do
  kubectl auth can-i $c --as=$SA
done > /tmp/c3-rbac.txt          # yes / no / no
kubectl -n c3-app create role secret-deleter --verb=delete --resource=secrets
kubectl -n c3-app create rolebinding deployer-secrets --role=secret-deleter --serviceaccount=c3-app:deployer
```
Write the file **before** granting the permission – the answers describe the original state.

### 14 – Immutable configuration
```bash
kubectl -n c3-app create cm c3-release --from-literal=VERSION=1.0 --dry-run=client -o yaml \
  | sed 's/^kind: ConfigMap/immutable: true\nkind: ConfigMap/' | kubectl apply -f -
kubectl -n c3-app set env deploy/web --from=configmap/c3-release
kubectl -n c3-app create cm c3-release-v2 --from-literal=VERSION=1.1
kubectl -n c3-app patch cm c3-release-v2 -p '{"immutable":true}'
kubectl -n c3-app set env deploy/web --from=configmap/c3-release-v2 --overwrite
```
Immutable ConfigMaps can't be changed – you create a new one and point the workload to it
(that's also what Kustomize's hash suffix does).

### 15 – NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: api-ingress, namespace: c3-net}
spec:
  podSelector: {matchLabels: {app: api}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector: {matchLabels: {tier: web}}
          podSelector: {matchLabels: {app: frontend}}
```

### 16 – Services
```bash
kubectl -n c3-net create svc clusterip api-direct --clusterip=None --tcp=8080:8080
kubectl -n c3-net set selector svc api-direct app=api
kubectl -n c3-net create svc externalname payments --external-name=payments.example.org
```

### 17 – Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: c3-hosts, namespace: c3-net}
spec:
  ingressClassName: traefik
  defaultBackend: {service: {name: www, port: {number: 80}}}
  rules:
    - host: api.c3.lab
      http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: api, port: {number: 8080}}}}]}
    - host: www.c3.lab
      http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: www, port: {number: 80}}}}]}
```
