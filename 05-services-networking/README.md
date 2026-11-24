# Domain 5 – Services and Networking (20 %)

Competencies from the curriculum:
- Demonstrate basic understanding of NetworkPolicies
- Provide and troubleshoot access to applications via services
- Use Ingress rules to expose applications

Add-on needed for 5.5–5.7: `./setup/install.sh traefik` (IngressClass `traefik`, NodePorts 30080/30443)

Preparation:
```bash
kubectl create ns net
kubectl -n net create deploy frontend --image=nginx:1.27 --replicas=2
kubectl -n net create deploy backend --image=registry.k8s.io/e2e-test-images/agnhost:2.53 -- /agnhost netexec --http-port=8080
kubectl -n net create deploy db --image=registry.k8s.io/pause:3.10
```

---

## Task 5.1 – Services ⏱ 5 min

1. Expose `frontend` as a ClusterIP service `frontend` on port 80.
2. Expose `backend` as service `backend` on port 80 → container port 8080.
3. Expose `frontend` additionally as NodePort service `frontend-ext` on node port `30100`.
4. From a temporary pod, reach `frontend`, `backend.net`, and
   `backend.net.svc.cluster.local`. Which short names work from another namespace?

---

## Task 5.2 – NetworkPolicy: ingress ⏱ 6 min

In namespace `net`:
1. `deny-ingress`: block all incoming traffic to all pods.
2. `backend-from-frontend`: pods `app=backend` accept traffic on 8080 only from pods `app=frontend`.
3. Test from a `frontend` pod (allowed) and from a temporary pod without labels (blocked).

---

## Task 5.3 – NetworkPolicy: egress ⏱ 6 min

1. Pods `app=backend` may only open connections to pods `app=db` on TCP 5432 and to DNS.
2. Label the namespace `net` with `env=dev`. Pods `app=frontend` may receive traffic from any pod in
   namespaces labeled `env=dev` – write this as a **single** additional policy `frontend-from-dev`.
3. What is the difference between these two `from` blocks?
   ```yaml
   - from:
       - namespaceSelector: {matchLabels: {env: dev}}
         podSelector: {matchLabels: {app: client}}
   ```
   ```yaml
   - from:
       - namespaceSelector: {matchLabels: {env: dev}}
       - podSelector: {matchLabels: {app: client}}
   ```

---

## Task 5.4 – Troubleshoot access via services ⏱ 10 min

```bash
kubectl apply -f 05-services-networking/scenarios/broken-services.yaml
```
From the pod `svc-debug/client`, the services `orders`, `users` and `billing` must answer on
port 80. Find and fix every problem **without** changing the Deployments. Keep the existing
NetworkPolicies and add or change only what's needed.

---

## Task 5.5 – Ingress: path-based routing ⏱ 6 min

Create an Ingress `app` in `net` (class `traefik`) for host `app.ckad.lab`:
- `/` (Prefix) → `frontend:80`
- `/api` (Prefix) → `backend:80`

Test: `curl -H 'Host: app.ckad.lab' localhost:30080/api`. Remember the NetworkPolicies from 5.2 –
traffic from the Ingress controller must be allowed!

---

## Task 5.6 – Ingress: host-based routing & default backend ⏱ 5 min

Create an Ingress `hosts` in `net` (class `traefik`):
- `frontend.ckad.lab` → `frontend:80`
- `backend.ckad.lab` → `backend:80`
- every other host → `frontend:80` (default backend)

---

## Task 5.7 – Ingress with TLS ⏱ 6 min

Create a self-signed certificate for `secure.ckad.lab`, a TLS Secret `secure-tls` in `net` and an
Ingress `secure` that serves `frontend` over HTTPS for that host.
Test: `curl -k --resolve secure.ckad.lab:30443:127.0.0.1 https://secure.ckad.lab:30443/`

---

## Task 5.8 – Headless services & DNS ⏱ 4 min

1. Create a headless service `backend-pods` for the `backend` pods.
2. Compare `nslookup backend` and `nslookup backend-pods` from a pod in `net`.
3. When would an application want the individual pod IPs instead of a single virtual IP?

---

✅ Check: `./05-services-networking/verify.sh`
📖 Solutions: [`SOLUTIONS.md`](SOLUTIONS.md)
