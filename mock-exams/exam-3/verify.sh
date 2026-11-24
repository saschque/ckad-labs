#!/usr/bin/env bash
# Scoring for CKAD mock exam 3
source "$(dirname "$0")/../../setup/exam-lib.sh"
SA=system:serviceaccount:c3-app:deployer

t1()  { is 1 "$(jp -n c3-app get job c3-tool -o jsonpath='{.status.succeeded}')" &&
        is c3-tool:1.0 "$(jp -n c3-app get job c3-tool -o jsonpath='{.spec.template.spec.containers[0].image}')"; }
t2()  { k -n c3-app exec c3-metrics -c adapter -- cat /data/metrics.json | jq -e '.requests > 0' >/dev/null; }
t3()  { is Parallel "$(jp -n c3-app get sts c3-queue -o jsonpath='{.spec.podManagementPolicy}')" &&
        is 3 "$(jp -n c3-app get sts c3-queue -o jsonpath='{.status.readyReplicas}')" &&
        is None "$(jp -n c3-app get svc c3-queue -o jsonpath='{.spec.clusterIP}')"; }
t4()  { is Recreate/busybox:1.37 "$(jp -n c3-app get deploy migrator -o jsonpath='{.spec.strategy.type}/{.spec.template.spec.containers[0].image}')"; }
t5()  { local v; v=$(helm search repo podinfo/podinfo --versions -o json 2>/dev/null | jq -r '.[1].version') &&
        grep -qx "$v" /tmp/c3-version.txt &&
        helm list -n c3-helm -o json 2>/dev/null | jq -e --arg v "$v" '.[] | select(.name=="c3-pinned" and (.chart | endswith($v)))' >/dev/null; }
t6()  { is 2/prod "$(jp -n c3-prod get deploy api -o jsonpath='{.spec.replicas}/{.spec.template.spec.containers[0].env[?(@.name=="ENV")].value}')"; }
t7()  { [[ $(sort /tmp/c3-deprecated.txt | tr '\n' ' ') == "CSIStorageCapacity EndpointSlice FlowSchema " ]]; }
t8()  { [[ -s /tmp/c3-500.log ]] && ! grep -v 'status=500' /tmp/c3-500.log >/dev/null && ! grep -q internal /tmp/c3-500.log; }
t9()  { is 1 "$(jp -n c3-app get deploy cache -o jsonpath='{.status.readyReplicas}')"; }
t10() { is false "$(jp -n c3-app get pod c3-token -o jsonpath='{.spec.automountServiceAccountToken}')" &&
        k -n c3-app exec c3-token -- cat /var/run/vault/token | cut -d. -f2 | base64 -d 2>/dev/null | grep -q vault; }
t11() { is '["NET_ADMIN","NET_RAW"]' "$(jp -n c3-app get pod c3-net-tool -o jsonpath='{.spec.containers[0].securityContext.capabilities.add}')" &&
        is '["ALL"]' "$(jp -n c3-app get pod c3-net-tool -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop}')"; }
t12() { is "3|2|300Mi" "$(jp -n c3-quota get quota c3-quota -o jsonpath='{.spec.hard.pods}|{.spec.hard.services}|{.spec.hard.requests\.memory}')" &&
        is 3 "$(jp -n c3-quota get deploy c3-filler -o jsonpath='{.status.readyReplicas}')"; }
t13() { [[ $(tr '\n' ' ' < /tmp/c3-rbac.txt) == "yes no no " ]] && is yes "$(k auth can-i delete secrets -n c3-app --as=$SA)"; }
t14() { is true "$(jp -n c3-app get cm c3-release -o jsonpath='{.immutable}')" &&
        is 1.1 "$(k -n c3-app exec deploy/web -- printenv VERSION)"; }
t15() { k -n c3-net get netpol api-ingress -o json | jq -e '.spec.ingress[0].from | length == 1 and .[0].namespaceSelector.matchLabels.tier == "web" and .[0].podSelector.matchLabels.app == "frontend"' >/dev/null &&
        k -n c3-web exec frontend -- wget -qO- -T 5 api.c3-net:8080 >/dev/null &&
        ! k -n c3-app exec frontend -- wget -qO- -T 5 api.c3-net:8080 >/dev/null; }
t16() { is None "$(jp -n c3-net get svc api-direct -o jsonpath='{.spec.clusterIP}')" &&
        is payments.example.org "$(jp -n c3-net get svc payments -o jsonpath='{.spec.externalName}')"; }
t17() { curl -s -m 5 -H 'Host: other.c3.lab' localhost:30080/ | grep -qi nginx &&
        is www "$(jp -n c3-net get ingress c3-hosts -o jsonpath='{.spec.defaultBackend.service.name}')" &&
        curl -s -m 5 -H 'Host: api.c3.lab' localhost:30080/hostname | grep -q api; }

run_exam "6:Fix an image" "7:Adapter pattern" "7:StatefulSet" "7:Recreate strategy" "6:Helm versions" \
  "7:Kustomize JSON patch" "5:Deprecated APIs" "5:Logs" "5:Fix a crashing app" "5:Projected token" \
  "5:Capabilities" "5:Quota" "5:RBAC check" "5:Immutable configuration" "7:NetworkPolicy" "6:Services" "7:Ingress"
