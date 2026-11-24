# CKAD Mock Exam 1 – 120 minutes

**Rules:** Set a 120-minute timer. Only use kubernetes.io/docs, kubernetes.io/blog and helm.sh/docs.
No reference solutions. Pass mark: **66 out of 100 points**.

Preparation (before starting the timer):
```bash
./setup/create-cluster.sh
./setup/install.sh traefik
./mock-exams/exam-1/setup.sh
```
Docker (or Podman) is needed for task 1.

---

### Task 1 – Build an image (6 points) · Design & build
`/tmp/c1/` contains a small app with a `Dockerfile`. Build the image `c1-app:1.0`, make it available
in the kind cluster and run it as pod `c1-app` in namespace `c1-app` (port 8080). The pod must not
try to pull the image from a registry.

### Task 2 – Multi-container pod (7 points) · Design & build
Create a pod `c1-web` in `c1-app`:
- init container `fetch` (busybox) writes `<h1>c1</h1>` to `/html/index.html`,
- main container `web` (`nginx:1.27`) serves `/html` as `/usr/share/nginx/html`,
- native sidecar `access-log` (busybox) tails `/var/log/nginx/access.log` (shared `emptyDir` mounted at
  `/var/log/nginx` in both containers).

### Task 3 – CronJob (7 points) · Design & build
Create a CronJob `c1-cleanup` in `c1-app` that runs every 10 minutes (`busybox:1.36`, command
`echo cleanup`), never runs two jobs concurrently, keeps 3 successful and 1 failed job, and whose
jobs are killed after 30 seconds.

### Task 4 – Rolling update (6 points) · Deployment
The Deployment `c1-app/api` runs `nginx:1.26`. Change its strategy to `maxSurge: 25%`,
`maxUnavailable: 0` and update it to `nginx:1.27`. The rollout must complete.

### Task 5 – Canary (7 points) · Deployment
The service `c1-app/shop` (selector `app=shop`) points to the Deployment `shop-v1` (3 replicas,
`nginx:1.26`). Create a Deployment `shop-v2` (`nginx:1.27`) so that **25 %** of the service's pods
run the new version, without changing the service.

### Task 6 – Helm (7 points) · Deployment
Install the chart `podinfo` from `https://stefanprodan.github.io/podinfo` as release `c1-podinfo`
in namespace `c1-helm` with `replicaCount=2` and `ui.message=c1`. Then upgrade it to
`replicaCount=3`, keeping the message.

### Task 7 – API deprecation (5 points) · Observability & maintenance
`/tmp/c1/old-manifests.yaml` cannot be applied. Fix the API versions (and any changed fields) and
apply it.

### Task 8 – Probes (5 points) · Observability & maintenance
Add to the Deployment `c1-app/api` a readiness probe (HTTP `/` port 80, every 5 s) and a liveness
probe (TCP port 80, every 10 s, initial delay 5 s).

### Task 9 – Debugging (5 points) · Observability & maintenance
The pod `c1-debug/worker` keeps crashing. Write the error line it prints before crashing to
`/tmp/c1-error.txt` and fix the pod so that it runs (you may recreate it).

### Task 10 – Configuration (5 points) · Environment, config & security
Create a pod `c1-config` in `c1-app` (busybox, `sleep 3600`) that gets all keys of the ConfigMap
`c1-settings` as env vars and the key `token` of the Secret `c1-secret` as file
`/etc/secret/token`.

### Task 11 – SecurityContext (5 points) · Environment, config & security
Create a pod `c1-secure` in `c1-app` (busybox, `sleep 3600`) that runs as user `2000`, cannot
escalate privileges, has a read-only root filesystem and drops all capabilities.

### Task 12 – ServiceAccount (5 points) · Environment, config & security
Create the ServiceAccount `c1-bot` in `c1-app` and give it permission to `get` and `list`
ConfigMaps in `c1-app`. Run the Deployment `api` with this ServiceAccount.

### Task 13 – Resources under a quota (5 points) · Environment, config & security
Namespace `c1-quota` has a ResourceQuota. Create a Deployment `c1-fit` there (`nginx:1.27`,
2 replicas) with suitable requests and limits so that both pods run.

### Task 14 – Custom resources (5 points) · Environment, config & security
A CRD for databases is installed. Create the custom resource `orders-db` in `c1-app` with the
engine `postgres` and 10 GB storage. Find out the field names yourself.

### Task 15 – NetworkPolicy (7 points) · Services & networking
In namespace `c1-net`, the pods `app=db` may only receive traffic on TCP 5432 from pods with
`role=api`. Name: `db-policy`.

### Task 16 – Service (6 points) · Services & networking
The pod `c1-net/client` cannot reach the service `c1-net/catalog`. Fix it without changing the
Deployment `catalog`.

### Task 17 – Ingress (7 points) · Services & networking
Create an Ingress `c1-ingress` in `c1-app` (class `traefik`) for host `c1.ckad.lab` that routes
`/api` to service `api:80` and `/shop` to service `shop:80`.

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-1/verify.sh`
