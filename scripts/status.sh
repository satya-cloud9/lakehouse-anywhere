#!/usr/bin/env bash
# Prints what's running and the port-forward command for each UI.
set -uo pipefail

echo "=== kind cluster ==="
kind get clusters 2>/dev/null | grep -q '^lakehouse$' && echo "lakehouse: up" || echo "lakehouse: not created (run 'make kind-up')"

echo ""
echo "=== floci (AWS emulator) ==="
curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1 && echo "floci: healthy (http://localhost:4566)" || echo "floci: not reachable (run 'make floci-up')"

echo ""
echo "=== Pods ==="
kubectl get pods -A 2>/dev/null || echo "(kind cluster not reachable)"

cat <<'EOF'

=== UI access (run these in separate terminals, then open the URL locally or via an SSH -L tunnel) ===

Trino UI:
  kubectl port-forward -n data-plane svc/trino 8080:8080
  -> http://localhost:8080

Kestra UI:
  kubectl port-forward -n data-plane svc/kestra 8081:8080
  -> http://localhost:8081

Grafana:
  kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
  -> http://localhost:3000  (admin / admin, per helm-values/kube-prometheus-stack-values.yaml)

MinIO console:
  kubectl port-forward -n data-plane svc/minio-console 9001:9001
  -> http://localhost:9001  (minioadmin / minioadmin)

If you're SSHing in from your laptop, tunnel these through the same SSH
session instead of running a browser on the box, e.g.:
  ssh -L 8080:localhost:8080 -L 3000:localhost:3000 <user>@<box>
then run the port-forward commands above on the box itself.
EOF
