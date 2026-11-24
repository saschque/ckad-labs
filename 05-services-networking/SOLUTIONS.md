# Domain 5 – Solutions

> Only look after your own attempt!

## 5.1 – Services
```bash
kubectl -n net expose deploy frontend --port=80
kubectl -n net expose deploy backend --port=80 --target-port=8080
kubectl -n net expose deploy frontend --name=frontend-ext --type=NodePort --port=80
kubectl -n net patch svc frontend-ext --type=json -p='[{"op":"replace","path":"/spec/ports/0/nodePort","value":30100}]'
kubectl -n net run t --rm -it --image=busybox:1.36 --restart=Never -- sh -c 'wget -qO- frontend | head -3; wget -qO- backend.net'
kubectl run t --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- backend.net     # from default: works
docker exec ckad-worker curl -s localhost:30100 | head -3
```
From another namespace, `backend` alone does **not** resolve (the search domain is
`<own-ns>.svc.cluster.local`) – use `backend.net` or the FQDN.

## 5.2 – NetworkPolicy: ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: deny-ingress, namespace: net}
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: backend-from-frontend, namespace: net}
spec:
  podSelector: {matchLabels: {app: backend}}
  policyTypes: [Ingress]
  ingress:
    - from: [{podSelector: {matchLabels: {app: frontend}}}]
      ports: [{protocol: TCP, port: 8080}]
```
```bash
kubectl -n net exec deploy/frontend -- curl -s -m 3 backend          # works
kubectl -n net run x --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- -T 3 backend   # timeout
```
The policy port is the **container** port (8080), not the service port (80) – policies see pod traffic.

## 5.3 – NetworkPolicy: egress
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: backend-egress, namespace: net}
spec:
  podSelector: {matchLabels: {app: backend}}
  policyTypes: [Egress]
  egress:
    - to: [{podSelector: {matchLabels: {app: db}}}]
      ports: [{protocol: TCP, port: 5432}]
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
          podSelector: {matchLabels: {k8s-app: kube-dns}}
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: frontend-from-dev, namespace: net}
spec:
  podSelector: {matchLabels: {app: frontend}}
  policyTypes: [Ingress]
  ingress:
    - from: [{namespaceSelector: {matchLabels: {env: dev}}}]
```
```bash
kubectl label ns net env=dev
```
- First block (one list entry with both selectors): pods `app=client` **in** namespaces `env=dev` (AND).
- Second block (two list entries): **all** pods in `env=dev` namespaces **or** pods `app=client`
  in the policy's own namespace (OR).

## 5.4 – Troubleshoot access via services
```bash
kubectl -n svc-debug get svc,endpointslices
kubectl -n svc-debug get netpol
```
| Service | Problem | Fix |
|---------|---------|-----|
| orders | Selector `app: order` – pods have `app: orders` → no endpoints | Fix the service selector |
| users | `targetPort: 8080`, nginx listens on 80 → refused; plus no NetworkPolicy allows it | Fix targetPort + allow the client |
| billing | Endpoints OK, but `deny-all` blocks it | Allow the client |

```bash
kubectl -n svc-debug patch svc orders -p '{"spec":{"selector":{"app":"orders"}}}'
kubectl -n svc-debug patch svc users --type=json -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-client, namespace: svc-debug}
spec:
  podSelector:
    matchExpressions: [{key: app, operator: In, values: [users, billing]}]
  policyTypes: [Ingress]
  ingress:
    - from: [{podSelector: {matchLabels: {role: client}}}]
EOF
for s in orders users billing; do kubectl -n svc-debug exec client -- wget -qO- -T 3 $s >/dev/null && echo "$s ok"; done
```
Checklist: **endpoints empty?** → selector/labels/readiness. **Connection refused?** → targetPort.
**Timeout?** → NetworkPolicy. **"bad address"?** → DNS name/namespace.

## 5.5 – Ingress: path-based routing
```bash
kubectl -n net create ingress app --class=traefik \
  --rule="app.ckad.lab/*=frontend:80" --rule="app.ckad.lab/api*=backend:80"
```
Allow traffic from the Ingress controller (namespace `traefik`):
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-ingress-controller, namespace: net}
spec:
  podSelector:
    matchExpressions: [{key: app, operator: In, values: [frontend, backend]}]
  policyTypes: [Ingress]
  ingress:
    - from: [{namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: traefik}}}]
```
`curl -s -H 'Host: app.ckad.lab' localhost:30080/api` → agnhost answers. In `kubectl create ingress`,
`path*` means `pathType: Prefix`, `path` without `*` means `Exact`.

## 5.6 – Host-based routing & default backend
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: hosts, namespace: net}
spec:
  ingressClassName: traefik
  defaultBackend:
    service: {name: frontend, port: {number: 80}}
  rules:
    - host: frontend.ckad.lab
      http:
        paths: [{path: /, pathType: Prefix, backend: {service: {name: frontend, port: {number: 80}}}}]
    - host: backend.ckad.lab
      http:
        paths: [{path: /, pathType: Prefix, backend: {service: {name: backend, port: {number: 80}}}}]
```

## 5.7 – Ingress with TLS
```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=secure.ckad.lab" \
  -addext "subjectAltName=DNS:secure.ckad.lab" -keyout /tmp/secure.key -out /tmp/secure.crt
kubectl -n net create secret tls secure-tls --cert=/tmp/secure.crt --key=/tmp/secure.key
kubectl -n net create ingress secure --class=traefik --rule="secure.ckad.lab/*=frontend:80,tls=secure-tls"
curl -sk --resolve secure.ckad.lab:30443:127.0.0.1 https://secure.ckad.lab:30443/ | head -3
```

## 5.8 – Headless services & DNS
```bash
kubectl -n net create svc clusterip backend-pods --clusterip=None --tcp=8080:8080
kubectl -n net set selector svc backend-pods app=backend
kubectl -n net scale deploy backend --replicas=2
kubectl -n net run d --rm -it --image=busybox:1.36 --restart=Never -- sh -c 'nslookup backend; nslookup backend-pods'
```
Use cases: client-side load balancing, peer discovery in clustered databases (Cassandra, etcd,
Kafka), StatefulSets with stable per-pod DNS names.
