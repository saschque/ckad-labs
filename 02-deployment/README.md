# Domain 2 – Application Deployment (20 %)

Competencies from the curriculum:
- Use Kubernetes primitives to implement common deployment strategies (e.g. blue/green or canary)
- Understand Deployments and how to perform rolling updates
- Use the Helm package manager to deploy existing packages
- Kustomize

All tasks run in namespace `deploy` unless stated otherwise: `kubectl create ns deploy`

---

## Task 2.1 – Rolling update ⏱ 5 min

1. Create a Deployment `shop` (image `nginx:1.26`, 6 replicas, label `app=shop`) with a rolling
   update strategy that never has fewer than 6 ready pods and at most 2 extra pods.
2. Set `minReadySeconds: 5` and `revisionHistoryLimit: 5`.
3. Update to `nginx:1.27` and watch the rollout. Then **pause** the Deployment, change the image to
   `nginx:1.27-alpine` and set the env `MODE=prod`, and **resume** it – how many rollouts happen?

---

## Task 2.2 – Rollback ⏱ 4 min

1. Update `shop` to `nginx:1.27-broken`. The rollout gets stuck.
2. Find out from the rollout history which revision ran `nginx:1.27-alpine` and roll back to it.
3. Set `progressDeadlineSeconds: 60`. What does Kubernetes report when a rollout takes longer?

---

## Task 2.3 – Recreate strategy ⏱ 3 min

Create a Deployment `legacy` (2 replicas, `nginx:1.27`) that must **never** have old and new
versions running at the same time. Update it to `nginx:1.27-alpine` and watch the pods.

---

## Task 2.4 – Blue/green ⏱ 8 min

1. Create Deployment `app-blue` (3 replicas, `nginx:1.26`, labels `app=web`, `version=blue`) and
   Deployment `app-green` (3 replicas, `nginx:1.27`, labels `app=web`, `version=green`).
2. Create a service `web` (port 80) that sends traffic **only to blue**.
3. Switch all traffic to green with a single command.
4. How would you roll back instantly?

---

## Task 2.5 – Canary ⏱ 6 min

Create the service `canary` (port 80, selector `app=frontend`) and two Deployments so that
roughly **20 %** of requests go to the new version:
- `frontend-stable`: `nginx:1.26`, labels `app=frontend`, `track=stable`
- `frontend-canary`: `nginx:1.27`, labels `app=frontend`, `track=canary`

Total: 5 pods. Then promote the canary to 100 %.

---

## Task 2.6 – Helm basics ⏱ 6 min

1. Add the repo `podinfo` (`https://stefanprodan.github.io/podinfo`) and list all available chart versions of `podinfo/podinfo`.
2. Install the chart as release `blog` in namespace `helm-apps` (create it) with `replicaCount=2`
   and a fixed, **older** chart version of your choice.
3. Upgrade the release to the newest version, keeping `replicaCount=2`.
4. Roll back to revision 1, then show the release's history and status.

---

## Task 2.7 – Helm values & templates ⏱ 6 min

1. Show all default values of `podinfo/podinfo` and save them to `/tmp/podinfo-defaults.yaml`.
2. Write `/tmp/podinfo-prod.yaml` that sets `replicaCount: 3`, `resources.requests.cpu: 50m` and
   `ui.message: "production"`.
3. Render the chart with this file **without installing it** to `/tmp/podinfo-rendered.yaml`, then
   install it as release `prod` in `helm-apps`.
4. Uninstall the release `blog` but keep its history (`--keep-history`).

---

## Task 2.8 – Kustomize overlays ⏱ 8 min

Create `/tmp/kust/` with:
- `base/`: Deployment `api` (`nginx:1.27`, 1 replica), Service `api` (port 80)
- `overlays/dev/`: namespace `kdev`, name suffix `-dev`, label `env=dev`
- `overlays/prod/`: namespace `kprod`, 3 replicas, image `nginx:1.27-alpine`, label `env=prod`,
  a ConfigMap `api-env` generated from the literal `LOG=warn`

Apply both overlays. Then change the replica count in prod with a **JSON 6902 patch** instead.

---

✅ Check: `./02-deployment/verify.sh`
📖 Solutions: [`SOLUTIONS.md`](SOLUTIONS.md)
