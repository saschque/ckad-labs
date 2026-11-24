#!/usr/bin/env bash
# Creates a local kind cluster (1 control plane + 2 workers) for the CKAD exercises.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ckad}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' already exists."
else
  kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-config.yaml"
fi
kubectl config use-context "kind-$CLUSTER_NAME"

# metrics-server (kubectl top / HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo "✅ Cluster ready: kind-$CLUSTER_NAME (nodes: $CLUSTER_NAME-control-plane, $CLUSTER_NAME-worker, $CLUSTER_NAME-worker2)"
kubectl get nodes
