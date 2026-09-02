#!/usr/bin/env bash
# Phase 4: create (or recreate) the kind cluster that stands in for EKS.
set -euo pipefail

cd "$(dirname "$0")/.."

if kind get clusters 2>/dev/null | grep -q '^lakehouse$'; then
  echo "kind cluster 'lakehouse' already exists. Delete and recreate? [y/N]"
  read -r ANSWER
  if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
    kind delete cluster --name lakehouse
  else
    echo "Keeping existing cluster."
    kubectl cluster-info --context kind-lakehouse
    exit 0
  fi
fi

echo "=== Creating kind cluster ==="
kind create cluster --config kind/kind-config.yaml

kubectl cluster-info --context kind-lakehouse
kubectl get nodes -o wide

echo ""
echo "Creating namespaces..."
kubectl apply -f k8s/namespaces.yaml

echo ""
echo "Next: make deploy"
