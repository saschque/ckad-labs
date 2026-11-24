#!/usr/bin/env bash
# Installs optional add-ons. Usage: ./setup/install.sh traefik cert-manager | all
set -euo pipefail

GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.3.0}"
helm_repo() { helm repo add "$1" "$2" >/dev/null 2>&1 || true; helm repo update "$1" >/dev/null; }

install_gateway_api() {
  kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
}

# Traefik = Ingress controller (IngressClass "traefik") + Gateway API implementation (GatewayClass "traefik")
install_traefik() {
  install_gateway_api
  helm_repo traefik https://traefik.github.io/charts
  helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
    --set providers.kubernetesGateway.enabled=true \
    --set gateway.enabled=false \
    --set service.type=NodePort \
    --set ports.web.nodePort=30080 \
    --set ports.websecure.nodePort=30443 \
    --set nodeSelector."kubernetes\.io/hostname"=ckad-control-plane \
    --set tolerations[0].key=node-role.kubernetes.io/control-plane \
    --set tolerations[0].effect=NoSchedule \
    --wait
}

install_cert_manager() {
  helm_repo jetstack https://charts.jetstack.io
  helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
    --set crds.enabled=true --wait
}

ALL=(traefik cert_manager)
[[ $# -eq 0 ]] && { echo "Usage: $0 <addon...>|all   Add-ons: ${ALL[*]} gateway_api"; exit 1; }
[[ "$1" == "all" ]] && set -- "${ALL[@]}"
for a in "$@"; do a="${a//-/_}"; echo "==> Installing $a"; "install_$a"; done
echo "✅ Done."
