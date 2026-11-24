# Domain 3 – Application Observability and Maintenance (15 %)

Competencies from the curriculum:
- Understand API deprecations
- Implement probes and health checks
- Use built-in CLI tools to monitor Kubernetes applications
- Utilize container logs
- Debugging in Kubernetes

Preparation: `kubectl create ns maint`

---

## Task 3.1 – API deprecations ⏱ 8 min

`scenarios/deprecated.yaml` contains four manifests with API versions that no longer exist.
1. Try `kubectl apply --dry-run=server -f scenarios/deprecated.yaml` and read the errors.
2. Find the current API version for each kind (`kubectl api-resources`, `kubectl explain`).
3. Write a converted, working version to `/tmp/converted.yaml` – watch out for fields that
   changed shape (the Ingress backend!). Create the Deployment `legacy` (`nginx:1.27`, label
   `app=legacy`) and a service `legacy` first, then apply the converted file.
4. How do you find out which API versions a cluster serves and which ones a manifest uses that
   will be removed in the next release?

---

## Task 3.2 – Probes ⏱ 6 min

Create a Deployment `probed` in `maint` (`nginx:1.27`, 2 replicas) with:
- `startupProbe`: HTTP GET `/` on port 80, every 2 s, up to 20 s in total,
- `readinessProbe`: HTTP GET `/` on port 80, every 5 s, 1 success needed,
- `livenessProbe`: **exec** probe `test -f /usr/share/nginx/html/index.html`, every 10 s,
  3 failures.

Then delete `index.html` in one pod and watch what happens (`RESTARTS`, events).

---

## Task 3.3 – Fix probe timing ⏱ 6 min

```bash
kubectl apply -f 03-observability-maintenance/scenarios/broken.yaml
```
The Deployment `debug/slow-start` keeps restarting and its pod is never `Ready`, although the app
itself works (it needs ~25 s to start). Fix the probes – two problems.

---

## Task 3.4 – Built-in monitoring ⏱ 5 min

1. Show the CPU and memory usage of all pods in all namespaces, sorted by memory.
2. Write the name of the pod in `kube-system` with the highest CPU usage to `/tmp/top-system-pod.txt`.
3. Show all events in namespace `debug` sorted by time, and only the `Warning` events.
4. Write the restart count of every pod in `debug` to `/tmp/restarts.txt` (`<pod> <restarts>`),
   using `custom-columns` or `jsonpath`.

---

## Task 3.5 – Container logs ⏱ 5 min

1. Create a pod `talker` with two containers: `a` prints `A <n>` every second, `b` prints
   `B <n>` to **stderr** every 2 s.
2. Show the last 5 lines of container `b` with timestamps.
3. Show the logs of both containers at once, prefixed with the container name.
4. Follow the logs of all pods with the label `app=probed` (task 3.2) at the same time.

---

## Task 3.6 – Ephemeral debug containers ⏱ 6 min

The pod `debug/distroless` runs an image without a shell.
1. Show that `kubectl exec ... -- sh` fails.
2. Attach an **ephemeral debug container** (`busybox:1.36`) that shares the process namespace of
   the container `app` and list its processes.
3. Create a **copy** of the pod named `distroless-copy` where the container image is replaced by
   `busybox:1.36` with `sleep 3600`.
4. Start a debug pod on node `ckad-worker` and look at the node's `/etc/hostname`.

---

## Task 3.7 – Debugging broken workloads ⏱ 10 min

From `scenarios/broken.yaml`, three Deployments in `debug` don't become ready:
`d1-api`, `d2-web`, `d3-worker`. Find the root cause of each (use events, `describe`, `logs`,
`logs --previous`) and fix it. Write the causes to `/tmp/debug-causes.txt` (`<name>: <cause>`).

---

## Task 3.8 – Port-forward and exec ⏱ 3 min

1. Forward local port 9090 to port 80 of the service of Deployment `probed` (create a service
   first) and fetch the page.
2. Run `nginx -T` inside one `probed` pod to print the active configuration.

---

✅ Check: `./03-observability-maintenance/verify.sh`
📖 Solutions: [`SOLUTIONS.md`](SOLUTIONS.md)
