# CKAD Mock Exam 3 – 120 minutes

**Rules:** 120-minute timer, only the official docs, no reference solutions. Pass mark: 66 %.

Preparation:
```bash
./setup/create-cluster.sh
./setup/install.sh traefik
./mock-exams/exam-3/setup.sh
```

---

### Task 1 – Fix an image (6 points) · Design & build
The image built from `/tmp/c3/Dockerfile` exits immediately with an error. Fix the Dockerfile,
build it as `c3-tool:1.0`, load it into the cluster and run it as Job `c3-tool` in `c3-app`.
The Job must complete successfully.

### Task 2 – Adapter pattern (7 points) · Design & build
Create a pod `c3-metrics` in `c3-app`: container `app` (busybox) writes `requests=<n>` to
`/data/raw.txt` every 3 s (overwrite); container `adapter` (busybox) reads it every 3 s and writes
`{"requests": <n>}` to `/data/metrics.json`. Shared `emptyDir`.

### Task 3 – StatefulSet (7 points) · Design & build
Create a headless service `c3-queue` and a StatefulSet `c3-queue` in `c3-app` (3 replicas,
`busybox:1.36`, `sleep infinity`) with a 50Mi volume per replica at `/var/queue`.
Pods must start **in parallel**, not one after another.

### Task 4 – Recreate strategy (7 points) · Deployment
The Deployment `c3-app/migrator` must never run two versions at the same time. Change its strategy
and update its image to `busybox:1.37`.

### Task 5 – Helm versions (6 points) · Deployment
Install the chart `podinfo/podinfo` (repo `https://stefanprodan.github.io/podinfo`) as release
`c3-pinned` in `c3-helm` in the **second-newest** chart version. Write that version to
`/tmp/c3-version.txt`.

### Task 6 – Kustomize JSON patch (7 points) · Deployment
`/tmp/c3-kust/base` contains a Deployment `api`. Create the overlay `/tmp/c3-kust/prod` (namespace
`c3-prod`) that uses a **JSON 6902** patch to add the env var `ENV=prod` to the first container and to
set 2 replicas. Apply it.

### Task 7 – Deprecated APIs (5 points) · Observability & maintenance
Write the `kind`s of all resources in `/tmp/c3/manifests.yaml` that use an API version that is not
served by this cluster to `/tmp/c3-deprecated.txt` (one per line).

### Task 8 – Logs (5 points) · Observability & maintenance
The pod `c3-logs/gateway` has two containers. Write all lines of the container `proxy` that contain
`status=500` to `/tmp/c3-500.log`.

### Task 9 – Fix a crashing app (5 points) · Observability & maintenance
The Deployment `c3-app/cache` restarts constantly. Find out why and fix it.

### Task 10 – Projected token (5 points) · Environment, config & security
Create a pod `c3-token` in `c3-app` (busybox, sleep) using the ServiceAccount `c3-client` (create it)
that has **no** default token mounted but a projected token for the audience `vault` at
`/var/run/vault/token`.

### Task 11 – Capabilities (5 points) · Environment, config & security
Create a pod `c3-net-tool` in `c3-app` (busybox, `sleep 3600`) that drops all capabilities and only
adds `NET_ADMIN` and `NET_RAW`, and runs with `privileged: false`.

### Task 12 – Quota (5 points) · Environment, config & security
Create a ResourceQuota `c3-quota` in `c3-quota` that allows at most 3 pods, 2 Services, and
`requests.memory: 300Mi`. Then create a Deployment `c3-filler` there (`nginx:1.27`, 3 replicas,
request `memory: 100Mi`) – all 3 pods must run.

### Task 13 – RBAC check (5 points) · Environment, config & security
Write to `/tmp/c3-rbac.txt` (`yes`/`no`, one per line, in this order) whether the ServiceAccount
`c3-app:deployer` can: 1) create deployments in `c3-app`, 2) delete secrets in `c3-app`,
3) list pods in `default`. Then grant it the missing permission to **delete secrets** in `c3-app`.

### Task 14 – Immutable configuration (5 points) · Environment, config & security
Create an immutable ConfigMap `c3-release` with `VERSION=1.0` in `c3-app`. Then "change" the version
to `1.1` for the Deployment `c3-app/web` (env from the ConfigMap) without deleting anything.

### Task 15 – NetworkPolicy (7 points) · Services & networking
The pods `app=api` in `c3-net` may only receive traffic from pods `app=frontend` in namespaces
labeled `tier=web` (both conditions must hold). Name: `api-ingress`.

### Task 16 – Services (6 points) · Services & networking
In `c3-net`, create a headless service `api-direct` for the `api` pods (port 8080) and an
ExternalName service `payments` that points to `payments.example.org`.

### Task 17 – Ingress (7 points) · Services & networking
Create an Ingress `c3-hosts` in `c3-net` (class `traefik`): `api.c3.lab` → `api:8080`,
`www.c3.lab` → `www:80`, and every other host → `www:80`.

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-3/verify.sh`
