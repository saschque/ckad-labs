#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
NS=config

section "4.1 CRDs & operators"
check "/tmp/cert-shortname.txt contains cert" grep -qw cert /tmp/cert-shortname.txt
eq "Certificate app-cert ready" "True" k -n $NS get certificate app-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
check "tls-app sees tls.crt" bash -c "kubectl -n $NS exec tls-app -- ls /etc/tls | grep -q tls.crt"

section "4.2 AuthN/AuthZ/admission"
eq "reader can list configmaps" "yes" k auth can-i list configmaps -n $NS --as=system:serviceaccount:$NS:reader
eq "reader can NOT delete pods" "no" k auth can-i delete pods -n $NS --as=system:serviceaccount:$NS:reader

section "4.3 ConfigMaps"
eq "APP_RETRIES=3" "3" k -n $NS exec cm-consumer -- printenv APP_RETRIES
eq "THEME=green" "green" k -n $NS exec cm-consumer -- printenv THEME
check "only main.conf mounted" bash -c "[[ \$(kubectl -n $NS exec cm-consumer -- ls /etc/conf.d) == main.conf ]]"

section "4.4 Secrets"
eq "regcred type" "kubernetes.io/dockerconfigjson" k -n $NS get secret regcred -o jsonpath='{.type}'
eq "web-tls type" "kubernetes.io/tls" k -n $NS get secret web-tls -o jsonpath='{.type}'
eq "DB_PASSWORD in secret-consumer" "Pa55w0rd" k -n $NS exec secret-consumer -- printenv DB_PASSWORD
eq "imagePullSecrets regcred" "regcred" k -n $NS get pod secret-consumer -o jsonpath='{.spec.imagePullSecrets[0].name}'

section "4.5 QoS"
eq "qos-guaranteed" "Guaranteed" k -n $NS get pod qos-guaranteed -o jsonpath='{.status.qosClass}'
eq "qos-burstable" "Burstable" k -n $NS get pod qos-burstable -o jsonpath='{.status.qosClass}'
eq "qos-besteffort" "BestEffort" k -n $NS get pod qos-besteffort -o jsonpath='{.status.qosClass}'

section "4.6 LimitRange & ResourceQuota"
eq "Quota pods=5" "5" k -n quota-demo get quota team-quota -o jsonpath='{.spec.hard.pods}'
eq "LimitRange max memory 256Mi" "256Mi" k -n quota-demo get limitrange container-limits -o jsonpath='{.spec.limits[0].max.memory}'

section "4.7 ServiceAccounts"
eq "app-sa automount off" "false" k -n $NS get sa app-sa -o jsonpath='{.automountServiceAccountToken}'
check "Projected token with audience my-api" bash -c \
  "kubectl -n $NS exec sa-pod -- cat /var/run/secrets/tokens/api | cut -d. -f2 | base64 -d 2>/dev/null | grep -q my-api"

section "4.8 SecurityContext"
check "secure runs as 1000:3000" bash -c "kubectl -n $NS exec secure -- id | grep -q 'uid=1000 gid=3000'"
check "Root filesystem read-only" bash -c "! kubectl -n $NS exec secure -- touch /test"
check "/tmp writable" kubectl -n $NS exec secure -- touch /tmp/test
eq "capabilities drop ALL" '["ALL"]' k -n $NS get pod secure -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop}'

section "4.9 Pod Security Admission"
eq "restricted-apps enforces restricted" "restricted" k get ns restricted-apps -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
eq "compliant running" "Running" k -n restricted-apps get pod compliant -o jsonpath='{.status.phase}'

summary
