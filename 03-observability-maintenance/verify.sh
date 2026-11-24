#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }

section "3.1 API deprecations"
check "/tmp/converted.yaml has no removed versions" bash -c "! grep -qE 'extensions/v1beta1|policy/v1beta1|autoscaling/v2beta2|batch/v1beta1' /tmp/converted.yaml"
for r in ingress/legacy-ingress pdb/legacy-pdb hpa/legacy-hpa cronjob/legacy-cron; do
  check "$r exists" k -n maint get $r
done

section "3.2 Probes"
check "exec liveness probe" bash -c "kubectl -n maint get deploy probed -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.exec.command}' | grep -q index.html"
check "startup + readiness probes" bash -c "kubectl -n maint get deploy probed -o json | jq -e '.spec.template.spec.containers[0] | .startupProbe and .readinessProbe'"

section "3.3 Probe timing"
eq "slow-start ready" "1" k -n debug get deploy slow-start -o jsonpath='{.status.readyReplicas}'
check "slow-start has a startupProbe or a liveness delay" bash -c \
  "kubectl -n debug get deploy slow-start -o json | jq -e '.spec.template.spec.containers[0] | .startupProbe or ((.livenessProbe.initialDelaySeconds // 0) >= 25)'"

section "3.4 Monitoring"
check "/tmp/top-system-pod.txt names a kube-system pod" bash -c "kubectl -n kube-system get pod \$(cat /tmp/top-system-pod.txt)"
check "/tmp/restarts.txt has pod + number per line" bash -c "grep -qE '^[a-z0-9-]+ +[0-9]+$' /tmp/restarts.txt"

section "3.5 Logs"
check "talker has containers a and b" bash -c "[[ \$(kubectl -n maint get pod talker -o jsonpath='{.spec.containers[*].name}') == 'a b' ]]"

section "3.6 Debugging"
check "distroless has an ephemeral container" bash -c "kubectl -n debug get pod distroless -o jsonpath='{.spec.ephemeralContainers[*].name}' | grep -q ."
eq "distroless-copy runs busybox" "busybox:1.36" k -n debug get pod distroless-copy -o jsonpath='{.spec.containers[?(@.name=="app")].image}'

section "3.7 Broken workloads"
for d in d1-api d2-web d3-worker; do
  eq "$d ready" "1" k -n debug get deploy $d -o jsonpath='{.status.readyReplicas}'
done
check "/tmp/debug-causes.txt has 3 lines" bash -c "[[ \$(grep -c . /tmp/debug-causes.txt) -ge 3 ]]"

section "3.8 Port-forward"
check "Service probed exists" k -n maint get svc probed

summary
