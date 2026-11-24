#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
NS=deploy

section "2.1 / 2.2 Rolling update & rollback"
eq "maxUnavailable=0" "0" k -n $NS get deploy shop -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}'
eq "maxSurge=2" "2" k -n $NS get deploy shop -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}'
eq "minReadySeconds=5" "5" k -n $NS get deploy shop -o jsonpath='{.spec.minReadySeconds}'
eq "Image after rollback: nginx:1.27-alpine" "nginx:1.27-alpine" k -n $NS get deploy shop -o jsonpath='{.spec.template.spec.containers[0].image}'
eq "progressDeadlineSeconds=60" "60" k -n $NS get deploy shop -o jsonpath='{.spec.progressDeadlineSeconds}'
eq "6 ready" "6" k -n $NS get deploy shop -o jsonpath='{.status.readyReplicas}'

section "2.3 Recreate"
eq "legacy uses Recreate" "Recreate" k -n $NS get deploy legacy -o jsonpath='{.spec.strategy.type}'

section "2.4 Blue/green"
eq "Service web → green" "green" k -n $NS get svc web -o jsonpath='{.spec.selector.version}'
eq "app-blue still running (instant rollback)" "3" k -n $NS get deploy app-blue -o jsonpath='{.status.readyReplicas}'

section "2.5 Canary"
eq "Service canary selects app=frontend only" '{"app":"frontend"}' k -n $NS get svc canary -o jsonpath='{.spec.selector}'
check "Stable promoted to nginx:1.27" bash -c "kubectl -n $NS get deploy frontend-stable -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -qx nginx:1.27"

section "2.6 / 2.7 Helm"
check "Release blog uninstalled with history" bash -c "helm list -n helm-apps --all -o json | jq -e '.[] | select(.name==\"blog\" and .status==\"uninstalled\")'"
eq "Release prod: 3 replicas" "3" k -n helm-apps get deploy prod-podinfo -o jsonpath='{.spec.replicas}'
check "/tmp/podinfo-defaults.yaml" grep -q replicaCount /tmp/podinfo-defaults.yaml
check "/tmp/podinfo-rendered.yaml contains a Deployment" grep -q 'kind: Deployment' /tmp/podinfo-rendered.yaml

section "2.8 Kustomize"
check "Deployment api-dev in kdev" k -n kdev get deploy api-dev
eq "kprod: 3 replicas" "3" k -n kprod get deploy api -o jsonpath='{.spec.replicas}'
eq "kprod: label env=prod" "prod" k -n kprod get deploy api -o jsonpath='{.metadata.labels.env}'
check "kprod: generated ConfigMap api-env-<hash>" bash -c "kubectl -n kprod get cm -o name | grep -qE 'api-env-[a-z0-9]+'"

summary
