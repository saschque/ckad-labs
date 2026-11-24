#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
NS=design

section "1.1 Build an image"
eq "web-v1 runs ckad-web:1.0" "ckad-web:1.0" k -n $NS get pod web-v1 -o jsonpath='{.spec.containers[0].image}'
eq "web-v1 running" "Running" k -n $NS get pod web-v1 -o jsonpath='{.status.phase}'
check "Page shows CKAD v1" bash -c "kubectl -n $NS exec web-v1 -- wget -qO- localhost | grep -q 'CKAD v1'"

section "1.2 Modify an image"
check "/tmp/ckad-web-2.0.tar exists" test -s /tmp/ckad-web-2.0.tar
eq "web-v2 running" "Running" k -n $NS get pod web-v2 -o jsonpath='{.status.phase}'
check "web-v2 does not run as root" bash -c "[[ \$(kubectl -n $NS exec web-v2 -- id -u) != 0 ]]"

section "1.3 Multi-stage build"
eq "goapp running" "Running" k -n $NS get pod goapp -o jsonpath='{.status.phase}'

section "1.4 Workload types"
check "DaemonSet log-agent" k -n $NS get ds log-agent
eq "StatefulSet db: 2 ready" "2" k -n $NS get sts db -o jsonpath='{.status.readyReplicas}'
eq "CronJob report at 23:00" "0 23 * * *" k -n $NS get cronjob report -o jsonpath='{.spec.schedule}'
check "Job migrate" k -n $NS get job migrate
eq "Deployment api: 3 replicas" "3" k -n $NS get deploy api -o jsonpath='{.spec.replicas}'

section "1.5 Job tuning"
eq "batch: 8/4/2/120/60" "8/4/2/120/60" k -n $NS get job batch -o jsonpath='{.spec.completions}/{.spec.parallelism}/{.spec.backoffLimit}/{.spec.activeDeadlineSeconds}/{.spec.ttlSecondsAfterFinished}'

section "1.6 Init container"
eq "waiter running" "Running" k -n $NS get pod waiter -o jsonpath='{.status.phase}'
check "Service backend exists" k -n $NS get svc backend

section "1.7 Sidecar"
eq "log-forwarder is a native sidecar" "Always" k -n $NS get pod app-with-sidecar -o jsonpath='{.spec.initContainers[0].restartPolicy}'
check "Sidecar logs contain requests" bash -c "kubectl -n $NS logs app-with-sidecar -c log-forwarder --tail=5 | grep -q 'request handled'"

section "1.8 Adapter"
check "metrics.json is JSON" bash -c "kubectl -n $NS exec metrics-pod -c adapter -- cat /data/metrics.json | jq -e .cpu"

section "1.9 Volumes"
eq "PVC uploads Bound" "Bound" k -n $NS get pvc uploads -o jsonpath='{.status.phase}'
check "≥ 2 files in /uploads (pod was recreated)" bash -c \
  "[[ \$(kubectl -n $NS exec deploy/uploader -- ls /uploads | wc -l) -ge 2 ]]"
check "emptyDir cache with sizeLimit" bash -c "kubectl -n $NS get deploy uploader -o jsonpath='{.spec.template.spec.volumes[*].emptyDir.sizeLimit}' | grep -q 64Mi"

summary
