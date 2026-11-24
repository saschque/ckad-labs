# Domain 1 – Application Design and Build (20 %)

Competencies from the curriculum:
- Define, build and modify container images
- Choose and use the right workload resource (Deployment, DaemonSet, CronJob, etc.)
- Understand multi-container Pod design patterns (e.g. sidecar, init and others)
- Utilize persistent and ephemeral volumes

All tasks run in namespace `design` unless stated otherwise: `kubectl create ns design`.
Image tasks need Docker (or Podman) on your machine.

---

## Task 1.1 – Build an image ⏱ 8 min

In `/tmp/app/`, create a tiny web app:
- `index.html` with the content `<h1>CKAD v1</h1>`
- a `Dockerfile` based on `nginx:1.27-alpine` that copies `index.html` to `/usr/share/nginx/html/`

1. Build the image as `ckad-web:1.0`.
2. Load it into the kind cluster (`kind load docker-image ... --name ckad`).
3. Run a pod `web-v1` in `design` with this image **without** pulling from a registry.
4. Check the page with `kubectl port-forward`.

---

## Task 1.2 – Modify an image ⏱ 8 min

Change the app from 1.1:
1. `index.html` now says `<h1>CKAD v2</h1>`.
2. The image must run as a **non-root** user: base it on `nginxinc/nginx-unprivileged:1.27-alpine`
   (listens on 8080).
3. Add the label `org.opencontainers.image.version=2.0`.
4. Build `ckad-web:2.0` and save it as an OCI/Docker archive to `/tmp/ckad-web-2.0.tar`.
5. Run it as pod `web-v2` and check that the container's user is not root.

---

## Task 1.3 – Multi-stage build ⏱ 8 min

Write a multi-stage `Dockerfile` in `/tmp/goapp/` for this Go program (`main.go`):
```go
package main
import ("fmt"; "net/http")
func main() {
  http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { fmt.Fprintln(w, "hello from go") })
  http.ListenAndServe(":8080", nil)
}
```
- Build stage: `golang:1.23`, static binary (`CGO_ENABLED=0`)
- Final stage: `gcr.io/distroless/static-debian12:nonroot`
Build it as `goapp:1.0`, compare its size with the build image and run it as pod `goapp`.

---

## Task 1.4 – Choose the right workload ⏱ 6 min

Create the right workload type for each requirement (all in `design`, image `busybox:1.36`):
1. `log-agent`: exactly one pod on every worker node, command `sleep infinity`.
2. `db`: 2 pods with stable names (`db-0`, `db-1`) and their own 100Mi volume each.
3. `report`: runs `date` once a day at 23:00.
4. `migrate`: runs `echo migrated` once to completion.
5. `api`: 3 interchangeable replicas with rolling updates (image `nginx:1.27`).

---

## Task 1.5 – Job tuning ⏱ 5 min

Create a Job `batch` that runs `sh -c 'echo processing; sleep 5'`:
- must succeed **8** times, at most **4** pods in parallel,
- at most 2 retries, the whole Job must not run longer than 120 s,
- finished Jobs are deleted after 60 s.

---

## Task 1.6 – Init container ⏱ 5 min

Create a pod `waiter` whose init container waits until the service `backend` in `design` can be
resolved via DNS (`nslookup`), and whose main container (`nginx:1.27`) only starts afterwards.
Create the service `backend` (any selector) only **after** the pod, and watch it start.

---

## Task 1.7 – Sidecar ⏱ 6 min

Create a pod `app-with-sidecar`:
- main container `app` (busybox) writes `$(date) request handled` to `/var/log/app/app.log` every 3 s,
- **native sidecar** `log-forwarder` (busybox) prints new lines of that file to stdout,
- both share an `emptyDir`.

Read the logs of the sidecar only.

---

## Task 1.8 – Adapter ⏱ 6 min

The legacy container `legacy` (busybox) writes lines like `2026-01-01T10:00:00 | cpu=42 | mem=512`
to `/data/metrics.txt` every 5 s. Add an **adapter** container `adapter` to the same pod
(`metrics-pod`) that converts the newest line into JSON `{"cpu":42,"mem":512}` and writes it to
`/data/metrics.json` every 5 s.

---

## Task 1.9 – Persistent and ephemeral volumes ⏱ 6 min

1. Create a PVC `uploads` (200Mi) and a Deployment `uploader` (1 replica, busybox) that mounts it
   at `/uploads` and writes a file `/uploads/<hostname>.txt` on start.
2. Delete the pod – is the file still there in the new pod?
3. Add a second volume to the same pod: a 64Mi `emptyDir` at `/tmp/cache`. What happens to its
   content when the pod is deleted? When only the container restarts?

---

✅ Check: `./01-design-build/verify.sh`
📖 Solutions: [`SOLUTIONS.md`](SOLUTIONS.md)
