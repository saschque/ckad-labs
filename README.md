# CKAD Labs – Practice exercises for the Certified Kubernetes Application Developer

Hands-on exercises for the **CKAD** exam by the Linux Foundation / CNCF.
The exam is **performance-based**: about 15–20 tasks in 120 minutes on live clusters, using the
command line. This repo mirrors the five official domains and runs on a local
[kind](https://kind.sigs.k8s.io) cluster.

| # | Domain | Weight | Folder |
|---|--------|--------|--------|
| 1 | Application Design and Build | 20 % | [`01-design-build`](01-design-build/) |
| 2 | Application Deployment | 20 % | [`02-deployment`](02-deployment/) |
| 3 | Application Observability and Maintenance | 15 % | [`03-observability-maintenance`](03-observability-maintenance/) |
| 4 | Application Environment, Configuration and Security | 25 % | [`04-environment-config-security`](04-environment-config-security/) |
| 5 | Services and Networking | 20 % | [`05-services-networking`](05-services-networking/) |

Plus:
- [`mock-exams/`](mock-exams/) – full mock exams (120 min, 100 points, automatic scoring)
- [`CHEATSHEET.md`](CHEATSHEET.md) – the most important commands at a glance

> ⚠️ The official curriculum (github.com/cncf/curriculum) is the reference. Check before the
> exam whether the competencies or the Kubernetes version have changed.

## Quick start

```bash
# 1. Create a local cluster (kind: 1 control plane + 2 workers, metrics-server)
./setup/create-cluster.sh

# 2. Optional add-ons (Traefik as Ingress controller, cert-manager as example operator)
./setup/install.sh traefik cert-manager

# 3. Work through the tasks
cat 01-design-build/README.md

# 4. Check your result
./01-design-build/verify.sh
```

Requirements: Docker (or Podman), kind, kubectl, helm, jq, openssl, curl.

## Low on RAM? (8 GB laptops)

```bash
./setup/resources.sh                    # what uses CPU/memory right now?
./setup/uninstall.sh traefik            # remove add-ons you don't need at the moment
```

- **Only install add-ons when a task needs them** (Traefik for Ingress/Gateway API, cert-manager
  for the operator tasks) and remove them afterwards.
- **Start over between domains:** `kind delete cluster --name ckad && ./setup/create-cluster.sh`
  takes about a minute and frees everything.
- **Close the rest:** browser tabs and IDEs compete for the same RAM.
- **Windows/WSL2:** cap the VM in `%UserProfile%\\.wslconfig` (`[wsl2]` → `memory=5GB`, `swap=4GB`),
  otherwise Windows and Docker fight over the RAM.
- The three-node cluster itself needs roughly 1.5–2 GB; many tasks rely on the worker nodes, so
  there is no single-node mode here.
Image tasks build locally and load the image into the cluster with `kind load docker-image`.

## Structure

```
0X-domain/
├── README.md        # tasks (scenario, requirements, time estimate)
├── SOLUTIONS.md     # reference solutions (only look AFTER your own attempt!)
├── verify.sh        # automatic check of your solution
└── scenarios/       # manifests with intentionally broken or outdated resources
```

## Mock exams

Each exam: `setup.sh` (prepares the scenario) → 120 min timer → `verify.sh` (point-based
scoring, pass mark 66 %) → `SOLUTIONS.md`. A fresh cluster per exam is recommended
(`kind delete cluster --name ckad && ./setup/create-cluster.sh`).

## Study strategy

1. **Speed is everything.** CKAD tasks are short but many. Generate YAML with
   `kubectl create/run ... --dry-run=client -o yaml` and only edit what's needed.
2. **Know the pod spec by heart:** probes, securityContext, volumes, env/envFrom, resources,
   init containers and native sidecars come up in almost every exam.
3. **Practice the docs:** you may use kubernetes.io and helm.sh during the exam. Know where the
   examples for NetworkPolicy, Ingress, probes and security contexts are.
4. **Always switch context/namespace first** – every task names the cluster and namespace.
5. **Time management:** skim all tasks, do quick wins first, flag long ones, come back later.

## Progress

- [ ] Domain 1 – Design & build
- [ ] Domain 2 – Deployment
- [ ] Domain 3 – Observability & maintenance
- [ ] Domain 4 – Environment, configuration & security
- [ ] Domain 5 – Services & networking
- [ ] Mock exam 1 ≥ 66 %
- [ ] Mock exam 2 ≥ 66 %
- [ ] Mock exam 3 ≥ 66 %
- [ ] Mock exam 4 ≥ 66 % in < 120 min
