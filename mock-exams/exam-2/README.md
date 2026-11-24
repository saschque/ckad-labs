# CKAD Mock Exam 2 – 120 minutes

**Rules:** 120-minute timer, only the official docs, no reference solutions. Pass mark: 66 %.

Preparation:
```bash
./setup/create-cluster.sh
./setup/install.sh traefik
./mock-exams/exam-2/setup.sh
```

---

### Task 1 – Modify an image (6 points) · Design & build
`/tmp/c2/Dockerfile` builds an image that runs as root. Change it so the container runs as the
non-root user `app` (UID 10001), build it as `c2-api:2.0` and save the image to
`/tmp/c2-api-2.0.tar`. Load it into the cluster and run it as pod `c2-api` in `c2-app`.

### Task 2 – Parallel Job (7 points) · Design & build
Create a Job `c2-render` in `c2-app` (`busybox:1.36`, `sh -c 'echo rendering; sleep 3'`) that
completes 10 times, runs 5 pods in parallel, retries at most 4 times and is removed 2 minutes after
it finished.

### Task 3 – Volumes (7 points) · Design & build
Create a PVC `c2-data` (100Mi) and a Deployment `c2-store` (1 replica, `busybox:1.36`,
`sleep 3600`) in `c2-app` that mounts the PVC at `/data` and an `emptyDir` with `medium: Memory`
(16Mi) at `/cache`.

### Task 4 – Blue/green (7 points) · Deployment
In `c2-app`, the service `checkout` points to the Deployment `checkout-blue`. Create
`checkout-green` (same labels except `color: green`, image `nginx:1.27`, 2 replicas) and switch the
service to green once it is ready. Keep blue running.

### Task 5 – Rollback (6 points) · Deployment
The Deployment `c2-app/catalog` was updated several times; the current version is broken. Roll back
to the newest revision that works (uses an image that exists).

### Task 6 – Kustomize (7 points) · Deployment
`/tmp/c2-kust/base` contains a Deployment `web`. Create the overlay `/tmp/c2-kust/staging` that
deploys to namespace `c2-staging`, adds the name prefix `staging-`, sets the image tag of `nginx` to
`1.27-alpine` and generates a ConfigMap `web-config` (literal `STAGE=staging`). Apply it.

### Task 7 – Startup probe (5 points) · Observability & maintenance
The Deployment `c2-app/legacy-app` needs about 30 s to start and is killed by its liveness probe
before that. Fix it with a startup probe – don't change the liveness probe.

### Task 8 – Resource monitoring (5 points) · Observability & maintenance
Write the name of the pod in `c2-load` with the highest memory usage to `/tmp/c2-top-mem.txt`.

### Task 9 – Debug container (5 points) · Observability & maintenance
The pod `c2-app/minimal` has no shell. Attach an ephemeral debug container (`busybox:1.36`) that
targets the container `app` and write the PID-1 command of the target container to `/tmp/c2-pid1.txt`.

### Task 10 – ConfigMap usage (5 points) · Environment, config & security
Create a pod `c2-env` in `c2-app` (busybox, `sleep 3600`) that loads all keys of the ConfigMap
`c2-flags` as env vars with the prefix `FLAG_` and mounts only the key `rules.json` of the same
ConfigMap as `/etc/app/rules.json`.

### Task 11 – Pod Security (5 points) · Environment, config & security
Make namespace `c2-secure` enforce the `restricted` Pod Security Standard, then create a pod
`c2-ok` there (`busybox:1.36`, `sleep 3600`) that is admitted.

### Task 12 – Secrets (5 points) · Environment, config & security
Create a Secret `c2-db` from the file `/tmp/c2/db.properties` (key name `db.properties`) and mount it
into a pod `c2-db-client` (busybox, sleep) at `/etc/db` with file mode `0400`.

### Task 13 – LimitRange (5 points) · Environment, config & security
In namespace `c2-limits`, every container without resources should automatically get requests
`100m`/`64Mi` and limits `250m`/`128Mi`. Containers must not request more than `512Mi` memory as limit.

### Task 14 – Extending Kubernetes (5 points) · Environment, config & security
Write the **scope** (Namespaced/Cluster) and the **short name** of the custom resource `Widget` to
`/tmp/c2-widget.txt` (format `scope=...` and `shortname=...`, one per line) and create a widget
`gizmo` with `spec.color: blue`.

### Task 15 – Egress policy (7 points) · Services & networking
Pods with `app=frontend` in `c2-net` may only send traffic to pods with `app=api` (TCP 8080) and to
DNS.

### Task 16 – NodePort (6 points) · Services & networking
Expose the Deployment `c2-net/api` as NodePort service `api-public` on port 80 → 8080 with the
node port `30222`.

### Task 17 – TLS Ingress (7 points) · Services & networking
Create a TLS Secret `c2-tls` (self-signed, `shop.c2.lab`) and an Ingress `c2-shop` in `c2-app`
(class `traefik`) that serves the service `checkout` over HTTPS for `shop.c2.lab`.

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-2/verify.sh`
