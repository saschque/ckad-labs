# Domain 4 – Application Environment, Configuration and Security (25 %)

Competencies from the curriculum:
- Discover and use resources that extend Kubernetes (CRD, Operators)
- Understand authentication, authorization and admission control
- Understand requests, limits, quotas
- Understand ConfigMaps
- Define resource requirements
- Create & consume Secrets
- Understand ServiceAccounts
- Understand Application Security (SecurityContexts, Capabilities, etc.)

Preparation: `kubectl create ns config` · Add-on for 4.1: `./setup/install.sh cert-manager`

---

## Task 4.1 – Discover and use CRDs & operators ⏱ 8 min

cert-manager (an operator) is installed.
1. List all API resources that cert-manager added, with their short names and whether they are
   namespaced. Write the short name of `Certificate` to `/tmp/cert-shortname.txt`.
2. Use `kubectl explain` to find the required fields of `Certificate.spec`.
3. Create an `Issuer` `selfsigned` (self-signed) and a `Certificate` `app-cert` in `config` for
   `app.ckad.lab`, stored in the secret `app-cert-tls`.
4. Mount the generated secret into a pod `tls-app` (busybox, sleep) at `/etc/tls` and list the files.

---

## Task 4.2 – Authentication, authorization, admission ⏱ 6 min

1. Which authorization modes and which **admission plugins** does the API server of this cluster
   use? (tip: the API server's static pod)
2. Can the ServiceAccount `config:default` list pods in its namespace? Create a ServiceAccount
   `reader` in `config` that may `get`/`list`/`watch` pods and ConfigMaps in `config`, and check
   both with `kubectl auth can-i`.
3. Create a pod in `config` that tries to request `cpu: 5` when a LimitRange with `max cpu: 1` is in
   place. Which admission step rejects it?

---

## Task 4.3 – ConfigMaps ⏱ 6 min

1. Create a ConfigMap `app-env` from an env file `/tmp/app.env` with `MODE=dev`, `RETRIES=3`,
   `COLOR=green`.
2. Create a ConfigMap `app-files` from a directory `/tmp/conf.d/` that contains `a.conf` and `b.conf`.
3. Create a pod `cm-consumer` (busybox, sleep) that
   - gets all keys of `app-env` as env vars with the prefix `APP_`,
   - gets only `COLOR` additionally as env var `THEME`,
   - mounts `app-files` at `/etc/conf.d`, but only `a.conf` (as `main.conf`).

---

## Task 4.4 – Secrets ⏱ 6 min

1. Create a generic Secret `db` with `user=app` and `password=Pa55w0rd`, and a TLS Secret `web-tls`
   from a self-signed certificate.
2. Create a `docker-registry` Secret `regcred` for `registry.example.com` (user `ci`, password `token`).
3. Create a pod `secret-consumer` (busybox, sleep) that uses `regcred` as image pull secret, gets
   `password` as env `DB_PASSWORD` and mounts `db` read-only at `/etc/db`.
4. Decode `password` from the command line. Why is a Secret not encrypted by default?

---

## Task 4.5 – Requests, limits & QoS ⏱ 5 min

Create three pods in `config` (`nginx:1.27`) and check their QoS class:
- `qos-guaranteed`: requests = limits = `100m` / `64Mi`
- `qos-burstable`: request `50m` / `32Mi`, limit memory `128Mi`
- `qos-besteffort`: no resources

Which one is evicted first when the node runs out of memory? What happens when a container exceeds
its memory limit, and what happens when it exceeds its CPU limit?

---

## Task 4.6 – LimitRange & ResourceQuota ⏱ 6 min

In namespace `quota-demo`:
1. LimitRange `container-limits`: default request `100m`/`64Mi`, default limit `200m`/`128Mi`,
   min memory `16Mi`, max memory `256Mi`.
2. ResourceQuota `team-quota`: `requests.cpu: 1`, `requests.memory: 512Mi`, `limits.memory: 1Gi`,
   max. 5 pods, max. 3 ConfigMaps. Which ConfigMap already counts against that limit in every namespace?
3. Create a Deployment with 8 replicas without resources. How many pods run? Show the quota usage.

---

## Task 4.7 – ServiceAccounts ⏱ 5 min

1. Create the ServiceAccount `app-sa` in `config` with `automountServiceAccountToken: false`.
2. Create a pod `sa-pod` (busybox, sleep) that runs as `app-sa` but **does** mount a token – as a
   projected volume at `/var/run/secrets/tokens/api` with audience `my-api` and 1 h expiry.
3. Decode the token's payload and check `aud` and `sub`.

---

## Task 4.8 – SecurityContext ⏱ 6 min

Create a pod `secure` in `config` (image `busybox:1.36`, command `sleep 3600`) with:
- pod level: `runAsUser: 1000`, `runAsGroup: 3000`, `fsGroup: 2000`, `seccompProfile: RuntimeDefault`
- container level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`,
  drop **all** capabilities, add only `NET_BIND_SERVICE`
- an `emptyDir` at `/tmp` so the app can still write temporary files

Check with `id`, `touch /test` (must fail) and `touch /tmp/test` (must work, owned by group 2000).

---

## Task 4.9 – Pod Security Admission ⏱ 5 min

1. Create the namespace `restricted-apps` that **enforces** the `restricted` Pod Security Standard.
2. Try `kubectl -n restricted-apps run web --image=nginx:1.27` and read the error.
3. Create a pod `compliant` (`nginxinc/nginx-unprivileged:1.27-alpine`) in that namespace that is
   admitted.

---

✅ Check: `./04-environment-config-security/verify.sh`
📖 Solutions: [`SOLUTIONS.md`](SOLUTIONS.md)
