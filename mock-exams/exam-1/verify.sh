#!/usr/bin/env bash
# Scoring for CKAD mock exam 1
source "$(dirname "$0")/../../setup/exam-lib.sh"

t1()  { is c1-app:1.0 "$(jp -n c1-app get pod c1-app -o jsonpath='{.spec.containers[0].image}')" &&
        is Running "$(jp -n c1-app get pod c1-app -o jsonpath='{.status.phase}')"; }
t2()  { is fetch "$(jp -n c1-app get pod c1-web -o jsonpath='{.spec.initContainers[0].name}')" &&
        is Always "$(jp -n c1-app get pod c1-web -o jsonpath='{.spec.initContainers[?(@.name=="access-log")].restartPolicy}')" &&
        k -n c1-app exec c1-web -c web -- curl -s localhost | grep -q c1; }
t3()  { is "*/10 * * * *|Forbid|3|1|30" "$(jp -n c1-app get cronjob c1-cleanup -o jsonpath='{.spec.schedule}|{.spec.concurrencyPolicy}|{.spec.successfulJobsHistoryLimit}|{.spec.failedJobsHistoryLimit}|{.spec.jobTemplate.spec.activeDeadlineSeconds}')"; }
t4()  { is "25%|0|nginx:1.27" "$(jp -n c1-app get deploy api -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}|{.spec.strategy.rollingUpdate.maxUnavailable}|{.spec.template.spec.containers[0].image}')" &&
        k -n c1-app rollout status deploy/api --timeout=10s >/dev/null; }
t5()  { is 1 "$(k -n c1-app get pods -l app=shop -o json | jq '[.items[] | select(.spec.containers[0].image=="nginx:1.27" and .status.phase=="Running")] | length')" &&
        is 4 "$(k -n c1-app get pods -l app=shop --field-selector=status.phase=Running --no-headers | wc -l | tr -d ' ')"; }
t6()  { is 3 "$(jp -n c1-helm get deploy c1-podinfo -o jsonpath='{.spec.replicas}')" &&
        helm get values c1-podinfo -n c1-helm 2>/dev/null | grep -q c1; }
t7()  { k -n c1-app get pdb api-pdb >/dev/null && k -n c1-app get ingress legacy >/dev/null; }
t8()  { k -n c1-app get deploy api -o json | jq -e '.spec.template.spec.containers[0] | (.readinessProbe.httpGet.port == 80) and (.livenessProbe.tcpSocket.port == 80)' >/dev/null; }
t9()  { grep -q 'QUEUE_URL is not set' /tmp/c1-error.txt && is Running "$(jp -n c1-debug get pod worker -o jsonpath='{.status.phase}')"; }
t10() { is production "$(k -n c1-app exec c1-config -- printenv MODE)" && is s3cr3t-t0ken "$(k -n c1-app exec c1-config -- cat /etc/secret/token)"; }
t11() { k -n c1-app exec c1-secure -- id -u | grep -qx 2000 && ! k -n c1-app exec c1-secure -- touch /x 2>/dev/null &&
        is false "$(jp -n c1-app get pod c1-secure -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}')"; }
t12() { is yes "$(k auth can-i list configmaps -n c1-app --as=system:serviceaccount:c1-app:c1-bot)" &&
        is c1-bot "$(jp -n c1-app get deploy api -o jsonpath='{.spec.template.spec.serviceAccountName}')"; }
t13() { is 2 "$(jp -n c1-quota get deploy c1-fit -o jsonpath='{.status.readyReplicas}')"; }
t14() { is postgres/10 "$(jp -n c1-app get database orders-db -o jsonpath='{.spec.engine}/{.spec.storageGB}')"; }
t15() { k -n c1-net get netpol db-policy -o json | jq -e '(.spec.podSelector.matchLabels.app=="db") and (.spec.ingress[0].ports[0].port==5432) and (.spec.ingress[0].from[0].podSelector.matchLabels.role=="api")' >/dev/null; }
t16() { k -n c1-net exec client -- wget -qO- -T 5 catalog >/dev/null; }
t17() { curl -s -m 5 -o /dev/null -w '%{http_code}' -H 'Host: c1.ckad.lab' localhost:30080/api | grep -qE '200|404' &&
        is "/api /shop" "$(jp -n c1-app get ingress c1-ingress -o jsonpath='{.spec.rules[0].http.paths[*].path}')"; }

run_exam "6:Build an image" "7:Multi-container pod" "7:CronJob" "6:Rolling update" "7:Canary" "7:Helm" \
  "5:API deprecation" "5:Probes" "5:Debugging" "5:Configuration" "5:SecurityContext" "5:ServiceAccount" \
  "5:Resources under a quota" "5:Custom resources" "7:NetworkPolicy" "6:Service" "7:Ingress"
