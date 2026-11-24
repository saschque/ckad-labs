#!/usr/bin/env bash
# Scoring for CKAD mock exam 2
source "$(dirname "$0")/../../setup/exam-lib.sh"

t1()  { test -s /tmp/c2-api-2.0.tar && is Running "$(jp -n c2-app get pod c2-api -o jsonpath='{.status.phase}')" &&
        is 10001 "$(k -n c2-app exec c2-api -- id -u)"; }
t2()  { is "10|5|4|120" "$(jp -n c2-app get job c2-render -o jsonpath='{.spec.completions}|{.spec.parallelism}|{.spec.backoffLimit}|{.spec.ttlSecondsAfterFinished}')"; }
t3()  { is Bound "$(jp -n c2-app get pvc c2-data -o jsonpath='{.status.phase}')" &&
        is Memory "$(jp -n c2-app get deploy c2-store -o jsonpath='{.spec.template.spec.volumes[?(@.name)].emptyDir.medium}')" &&
        is 1 "$(jp -n c2-app get deploy c2-store -o jsonpath='{.status.readyReplicas}')"; }
t4()  { is green "$(jp -n c2-app get svc checkout -o jsonpath='{.spec.selector.color}')" &&
        is 2 "$(jp -n c2-app get deploy checkout-green -o jsonpath='{.status.readyReplicas}')" &&
        is 2 "$(jp -n c2-app get deploy checkout-blue -o jsonpath='{.status.readyReplicas}')"; }
t5()  { is nginx:1.26 "$(jp -n c2-app get deploy catalog -o jsonpath='{.spec.template.spec.containers[0].image}')" &&
        k -n c2-app rollout status deploy/catalog --timeout=10s >/dev/null; }
t6()  { is nginx:1.27-alpine "$(jp -n c2-staging get deploy staging-web -o jsonpath='{.spec.template.spec.containers[0].image}')" &&
        k -n c2-staging get cm -o name | grep -qE 'staging-web-config-[a-z0-9]+'; }
t7()  { is 1 "$(jp -n c2-app get deploy legacy-app -o jsonpath='{.status.readyReplicas}')" &&
        k -n c2-app get deploy legacy-app -o json | jq -e '.spec.template.spec.containers[0] | .startupProbe and (.livenessProbe.periodSeconds == 5)' >/dev/null; }
t8()  { grep -qx big /tmp/c2-top-mem.txt; }
t9()  { [[ -n $(jp -n c2-app get pod minimal -o jsonpath='{.spec.ephemeralContainers[*].name}') ]] && grep -q pause /tmp/c2-pid1.txt; }
t10() { is true "$(k -n c2-app exec c2-env -- printenv FLAG_DARK_MODE)" && k -n c2-app exec c2-env -- cat /etc/app/rules.json | grep -q maxItems; }
t11() { is restricted "$(jp get ns c2-secure -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" &&
        is Running "$(jp -n c2-secure get pod c2-ok -o jsonpath='{.status.phase}')"; }
t12() { is 256 "$(jp -n c2-app get pod c2-db-client -o jsonpath='{.spec.volumes[0].secret.defaultMode}')" &&
        k -n c2-app exec c2-db-client -- cat /etc/db/db.properties | grep -q c2pass; }
t13() { is "100m|64Mi|250m|128Mi|512Mi" "$(jp -n c2-limits get limitrange -o jsonpath='{.items[0].spec.limits[0].defaultRequest.cpu}|{.items[0].spec.limits[0].defaultRequest.memory}|{.items[0].spec.limits[0].default.cpu}|{.items[0].spec.limits[0].default.memory}|{.items[0].spec.limits[0].max.memory}')"; }
t14() { grep -qx 'scope=Cluster' /tmp/c2-widget.txt && grep -qx 'shortname=wdg' /tmp/c2-widget.txt && is blue "$(jp get widget gizmo -o jsonpath='{.spec.color}')"; }
t15() { k -n c2-net exec frontend -- wget -qO- -T 5 api:8080 >/dev/null &&
        k -n c2-net get netpol -o json | jq -e '[.items[] | select(.spec.podSelector.matchLabels.app=="frontend" and (.spec.policyTypes | index("Egress")))] | length > 0' >/dev/null; }
t16() { is 30222 "$(jp -n c2-net get svc api-public -o jsonpath='{.spec.ports[0].nodePort}')" &&
        docker exec ckad-worker curl -sf -m 5 localhost:30222 >/dev/null; }
t17() { is c2-tls "$(jp -n c2-app get ingress c2-shop -o jsonpath='{.spec.tls[0].secretName}')" &&
        curl -sk -m 5 --resolve shop.c2.lab:30443:127.0.0.1 https://shop.c2.lab:30443/ | grep -qi nginx; }

run_exam "6:Modify an image" "7:Parallel Job" "7:Volumes" "7:Blue/green" "6:Rollback" "7:Kustomize" \
  "5:Startup probe" "5:Resource monitoring" "5:Debug container" "5:ConfigMap usage" "5:Pod Security" \
  "5:Secrets" "5:LimitRange" "5:Extending Kubernetes" "7:Egress policy" "6:NodePort" "7:TLS Ingress"
