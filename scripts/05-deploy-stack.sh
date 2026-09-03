#!/usr/bin/env bash
# Phase 5: install MinIO, Postgres+Kestra, Trino, and the observability
# stack into the kind cluster.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Adding Helm repos ==="
helm repo add minio https://charts.min.io/ || true
helm repo add trino https://trinodb.github.io/charts || true
helm repo add kestra https://helm.kestra.io || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update

echo "=== Installing MinIO ==="
helm upgrade --install minio minio/minio \
  -n data-plane --create-namespace \
  -f helm-values/minio-values.yaml \
  --wait --timeout 5m

echo "=== Deploying Postgres for Kestra ==="
kubectl apply -f k8s/postgres-kestra.yaml
kubectl -n data-plane rollout status deployment/kestra-postgres --timeout=120s

# --- Bridge networking: let pods in the kind cluster reach the floci
# container running via docker compose on the host. Docker's embedded DNS
# only resolves container names within a shared user-defined network, and
# pods don't share the node's Docker DNS anyway — so we connect floci to
# kind's Docker network and address it by IP, not name. See README for why
# this is needed instead of `host.docker.internal` (works on Docker
# Desktop, not reliably on Linux Docker).
echo "=== Bridging floci into the kind Docker network ==="
docker network connect kind lakehouse-floci 2>/dev/null || echo "(already connected, or 'kind' network doesn't exist yet — run this after 'make kind-up')"
FLOCI_IP=$(docker inspect -f '{{ (index .NetworkSettings.Networks "kind").IPAddress }}' lakehouse-floci)
if [ -z "$FLOCI_IP" ]; then
  echo "Could not determine floci's IP on the kind network. Run:"
  echo "  docker inspect lakehouse-floci | grep -A5 Networks"
  echo "and paste the output back."
  exit 1
fi
echo "floci reachable from pods at: $FLOCI_IP:4566"

echo "=== Installing Trino ==="
sed "s/AWS_EMULATOR_HOST/${FLOCI_IP}/" helm-values/trino-values.yaml > /tmp/trino-values-rendered.yaml
helm upgrade --install trino trino/trino \
  -n data-plane --create-namespace \
  -f /tmp/trino-values-rendered.yaml \
  --wait --timeout 5m

echo "=== Installing Kestra ==="
helm upgrade --install kestra kestra/kestra \
  -n data-plane --create-namespace \
  -f helm-values/kestra-values.yaml \
  --wait --timeout 5m

echo "=== Installing observability stack ==="
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n observability --create-namespace \
  -f helm-values/kube-prometheus-stack-values.yaml \
  --wait --timeout 8m

helm upgrade --install loki grafana/loki \
  -n observability --create-namespace \
  -f helm-values/loki-values.yaml \
  --wait --timeout 5m

helm upgrade --install tempo grafana/tempo \
  -n observability --create-namespace \
  -f helm-values/tempo-values.yaml \
  --wait --timeout 5m

echo ""
echo "=== Everything installed. Run 'make status' for endpoints. ==="
