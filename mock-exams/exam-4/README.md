# CKAD Mock Exam 4 – 120 minutes

**Rules:** 120-minute timer, only the official docs, no reference solutions. Pass mark: 66 %.

Preparation:
```bash
./setup/create-cluster.sh
./setup/install.sh traefik
./mock-exams/exam-4/setup.sh
```

---

### Task 1 – Image with build arguments (6 points) · Design & build
Write `/tmp/c4/Dockerfile` (base `alpine:3.20`) with a build argument `APP_VERSION` that is stored
in the env var `APP_VERSION` and printed by the container's command (`echo "version $APP_VERSION";
sleep 3600`). Build `c4-app:3.1` with `APP_VERSION=3.1`, load it and run it as pod `c4-app` in `c4-app`.

### Task 2 – Wait for dependencies (7 points) · Design & build
Create a Deployment `c4-frontend` in `c4-app` (`nginx:1.27`) whose pods only start after the service
`c4-backend` answers HTTP on port 80 (init container with `wget`). Then create the Deployment and
service `c4-backend` (`nginx:1.27`) so that the frontend starts.

### Task 3 – Suspended CronJob (7 points) · Design & build
Create a CronJob `c4-backup` in `c4-app` (every day at 01:15, `busybox:1.36`, `echo backup`) that is
**suspended**, uses `restartPolicy: Never` and a backoff limit of 1. Start one run manually as Job
`c4-backup-manual`.

### Task 4 – Promote a canary (7 points) · Deployment
In `c4-app`, the service `web` serves pods from `web-stable` (`nginx:1.26`) and `web-canary`
(`nginx:1.27`). Promote the canary: all `web` pods must run `nginx:1.27`, the canary Deployment
must be gone, and the service must never have zero endpoints.

### Task 5 – Batched changes (6 points) · Deployment
Make three changes to the Deployment `c4-app/api` – image `nginx:1.27-alpine`, env `LOG_LEVEL=debug`,
memory limit `128Mi` – so that they result in **exactly one** new ReplicaSet.

### Task 6 – Helm template (7 points) · Deployment
Render the chart `podinfo/podinfo` (repo `https://stefanprodan.github.io/podinfo`) as release name
`c4-render` with `replicaCount=2` to `/tmp/c4-rendered.yaml` and apply it with `kubectl` to
namespace `c4-helm`.

### Task 7 – Exec and TCP probes (5 points) · Observability & maintenance
Create a pod `c4-redis` in `c4-app` (`redis:7`) with a readiness probe that runs `redis-cli ping`
and a liveness probe on TCP port 6379 (every 10 s).

### Task 8 – Events (5 points) · Observability & maintenance
Write the names of all pods in `c4-broken` that currently have **Warning** events to
`/tmp/c4-warning-pods.txt` (one per line, sorted, no duplicates).

### Task 9 – Debug a copy (5 points) · Observability & maintenance
The pod `c4-app/app-locked` crashes immediately. Create a copy of it named `app-locked-debug` in which
the container runs `sleep 3600` instead, so you can inspect its filesystem. Write the content of
`/config/app.conf` from inside the copy to `/tmp/c4-appconf.txt`.

### Task 10 – Secret from files (5 points) · Environment, config & security
Create a Secret `c4-creds` from the files `/tmp/c4/username` and `/tmp/c4/password`. Create a pod
`c4-creds-user` (busybox, sleep) that exposes them as env vars `USERNAME` and `PASSWORD`.

### Task 11 – fsGroup (5 points) · Environment, config & security
Create a pod `c4-shared` in `c4-app` (busybox, `sleep 3600`) running as user `1001` with `fsGroup: 4000`
and a read-only root filesystem; it mounts an `emptyDir` at `/work`. Files created in `/work` must
belong to group `4000`.

### Task 12 – ServiceAccount (5 points) · Environment, config & security
Create the ServiceAccount `c4-watcher` (no automatic token mount) in `c4-app`, allow it to `watch`
and `list` pods, and use it for a pod `c4-watcher` (busybox, sleep) that **does** mount the token.

### Task 13 – QoS (5 points) · Environment, config & security
Change the Deployment `c4-app/critical` so that its pods get the QoS class **Guaranteed**.

### Task 14 – Custom resource (5 points) · Environment, config & security
A CRD for `Feature` flags exists. Create the feature `dark-mode` in `c4-app` that is enabled for 25 %
of users. Use `kubectl explain` to find the fields.

### Task 15 – Service troubleshooting (7 points) · Services & networking
The pod `c4-net/tester` gets no answer from the service `c4-net/inventory`. Fix it without
changing the Deployment `inventory`.

### Task 16 – NetworkPolicy (6 points) · Services & networking
Pods in `c4-net` with `app=inventory` may receive traffic only from namespaces with the label
`purpose=monitoring` **or** from pods with `role=tester` in `c4-net`. Name: `inventory-access`.

### Task 17 – Ingress (7 points) · Services & networking
Create an Ingress `c4-paths` in `c4-app` (class `traefik`, host `c4.ckad.lab`) where `/` goes to
`web:80` and the **exact** path `/healthz` goes to `api:80`.

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-4/verify.sh`
