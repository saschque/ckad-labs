#!/usr/bin/env bash
# Scoring for CKAD mock exam 4
source "$(dirname "$0")/../../setup/exam-lib.sh"

t1()  { grep -q 'ARG APP_VERSION' /tmp/c4/Dockerfile && k -n c4-app logs c4-app | grep -q 'version 3.1'; }
t2()  { is wait-backend-ok "$(k -n c4-app get deploy c4-frontend -o json | jq -r 'if (.spec.template.spec.initContainers | length) > 0 then "wait-backend-ok" else "no" end')" &&
        is 1 "$(jp -n c4-app get deploy c4-frontend -o jsonpath='{.status.readyReplicas}')"; }
t3()  { is "15 1 * * *|true|1|Never" "$(jp -n c4-app get cronjob c4-backup -o jsonpath='{.spec.schedule}|{.spec.suspend}|{.spec.jobTemplate.spec.backoffLimit}|{.spec.jobTemplate.spec.template.spec.restartPolicy}')" &&
        k -n c4-app get job c4-backup-manual >/dev/null; }
t4()  { ! k -n c4-app get deploy web-canary >/dev/null &&
        is "nginx:1.27" "$(k -n c4-app get pods -l app=web -o jsonpath='{.items[*].spec.containers[0].image}' | tr ' ' '\n' | sort -u)"; }
t5()  { is "nginx:1.27-alpine|debug|128Mi" "$(jp -n c4-app get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}|{.spec.template.spec.containers[0].env[?(@.name=="LOG_LEVEL")].value}|{.spec.template.spec.containers[0].resources.limits.memory}')" &&
        is 2 "$(k -n c4-app get rs -l app=api --no-headers | wc -l | tr -d ' ')"; }
t6()  { grep -q 'kind: Deployment' /tmp/c4-rendered.yaml && is 2 "$(jp -n c4-helm get deploy c4-render-podinfo -o jsonpath='{.spec.replicas}')"; }
t7()  { is redis-cli "$(jp -n c4-app get pod c4-redis -o jsonpath='{.spec.containers[0].readinessProbe.exec.command[0]}')" &&
        is 6379 "$(jp -n c4-app get pod c4-redis -o jsonpath='{.spec.containers[0].livenessProbe.tcpSocket.port}')" &&
        is true "$(jp -n c4-app get pod c4-redis -o jsonpath='{.status.containerStatuses[0].ready}')"; }
t8()  { [[ $(tr '\n' ' ' < /tmp/c4-warning-pods.txt) == "crash-loop pull-fail unschedulable " ]]; }
t9()  { is Running "$(jp -n c4-app get pod app-locked-debug -o jsonpath='{.status.phase}')" && grep -q 'limit=42' /tmp/c4-appconf.txt; }
t10() { is c4-Pa55 "$(k -n c4-app exec c4-creds-user -- printenv PASSWORD)" && is admin "$(k -n c4-app exec c4-creds-user -- printenv USERNAME)"; }
t11() { k -n c4-app exec c4-shared -- sh -c 'touch /work/f && stat -c %g /work/f' | grep -qx 4000 &&
        ! k -n c4-app exec c4-shared -- touch /f 2>/dev/null; }
t12() { is false "$(jp -n c4-app get sa c4-watcher -o jsonpath='{.automountServiceAccountToken}')" &&
        is yes "$(k auth can-i watch pods -n c4-app --as=system:serviceaccount:c4-app:c4-watcher)" &&
        k -n c4-app exec c4-watcher -- ls /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null; }
t13() { is Guaranteed "$(k -n c4-app get pods -l app=critical -o jsonpath='{.items[0].status.qosClass}')"; }
t14() { is true/25 "$(jp -n c4-app get feature dark-mode -o jsonpath='{.spec.enabled}/{.spec.rollout.percentage}')"; }
t15() { k -n c4-net exec tester -- wget -qO- -T 5 inventory >/dev/null; }
t16() { k -n c4-net get netpol inventory-access -o json | jq -e '.spec.ingress[0].from | length == 2' >/dev/null; }
t17() { is "Prefix Exact" "$(jp -n c4-app get ingress c4-paths -o jsonpath='{.spec.rules[0].http.paths[*].pathType}')" &&
        curl -s -m 5 -H 'Host: c4.ckad.lab' localhost:30080/ | grep -qi nginx; }

run_exam "6:Image with build args" "7:Wait for dependencies" "7:Suspended CronJob" "7:Promote a canary" \
  "6:Batched changes" "7:Helm template" "5:Exec and TCP probes" "5:Events" "5:Debug a copy" "5:Secret from files" \
  "5:fsGroup" "5:ServiceAccount" "5:QoS" "5:Custom resource" "7:Service troubleshooting" "6:NetworkPolicy" "7:Ingress"
