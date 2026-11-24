#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
NS=net

section "5.1 Services"
eq "backend targetPort 8080" "8080" k -n $NS get svc backend -o jsonpath='{.spec.ports[0].targetPort}'
eq "frontend-ext nodePort 30100" "30100" k -n $NS get svc frontend-ext -o jsonpath='{.spec.ports[0].nodePort}'

section "5.2 / 5.3 NetworkPolicies"
for np in deny-ingress backend-from-frontend backend-egress frontend-from-dev; do
  check "NetworkPolicy $np exists" k -n $NS get netpol $np
done
check "frontend reaches backend" kubectl -n $NS exec deploy/frontend -- curl -sf -m 5 backend
check "unlabeled pod is blocked from backend" bash -c "! kubectl -n $NS run vx --rm -i --image=busybox:1.36 --restart=Never -- wget -qO- -T 4 backend"
eq "Namespace net has env=dev" "dev" k get ns $NS -o jsonpath='{.metadata.labels.env}'

section "5.4 Troubleshooting"
for s in orders users billing; do
  check "client reaches $s" kubectl -n svc-debug exec client -- wget -qO- -T 5 $s
done
check "Original NetworkPolicies kept" bash -c "kubectl -n svc-debug get netpol deny-all allow-api"

section "5.5 / 5.6 Ingress"
check "app.ckad.lab/api → backend" bash -c "curl -sf -m 5 -H 'Host: app.ckad.lab' localhost:30080/api | grep -qiv nginx"
check "frontend.ckad.lab → nginx" bash -c "curl -sf -m 5 -H 'Host: frontend.ckad.lab' localhost:30080/ | grep -qi nginx"
check "hosts has a default backend" bash -c "kubectl -n $NS get ingress hosts -o jsonpath='{.spec.defaultBackend.service.name}' | grep -q frontend"

section "5.7 TLS"
eq "secure uses secure-tls" "secure-tls" k -n $NS get ingress secure -o jsonpath='{.spec.tls[0].secretName}'
check "HTTPS works" bash -c "curl -sfk -m 5 --resolve secure.ckad.lab:30443:127.0.0.1 https://secure.ckad.lab:30443/ | grep -qi nginx"

section "5.8 Headless"
eq "backend-pods headless" "None" k -n $NS get svc backend-pods -o jsonpath='{.spec.clusterIP}'

summary
