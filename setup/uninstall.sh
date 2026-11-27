#!/usr/bin/env bash
# Removes add-ons again to free resources. Usage: ./setup/uninstall.sh traefik cert-manager | all
set -uo pipefail
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.3.0}"

uninstall_traefik()      { helm uninstall traefik -n traefik --wait 2>/dev/null; kubectl delete ns traefik --ignore-not-found --wait=false; }
uninstall_cert_manager() { helm uninstall cert-manager -n cert-manager --wait 2>/dev/null; kubectl delete ns cert-manager --ignore-not-found --wait=false; }
uninstall_gateway_api()  { kubectl delete -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml" --ignore-not-found; }

ALL=(traefik cert_manager)
[[ $# -eq 0 ]] && { echo "Usage: $0 <addon...>|all   Add-ons: ${ALL[*]} gateway_api"; exit 1; }
[[ "$1" == "all" ]] && set -- "${ALL[@]}"
for a in "$@"; do a="${a//-/_}"; echo "==> Removing $a"; "uninstall_$a"; done
echo "✅ Done. Check: ./setup/resources.sh"
