#!/usr/bin/env bash
# Prints what's running (emulator, cluster, per-stage Terraform outputs)
# and the port-forward command for each UI, for whichever PROVIDER/TENANT
# you're pointed at.
#
# Usage: PROVIDER=baremetal|aws|gcp|azure TENANT=tenant-a bash scripts/status.sh
set -uo pipefail

cd "$(dirname "$0")/.."

PROVIDER="${PROVIDER:-aws}"
TENANT="${TENANT:-tenant-a}"

echo "=== Emulator (PROVIDER=$PROVIDER) ==="
case "$PROVIDER" in
  baremetal)
    echo "baremetal: no emulator -- talking directly to the mini PC over SSH."
    ;;
  aws)
    curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1 \
      && echo "floci: healthy (http://localhost:4566)" \
      || echo "floci: not reachable (run 'PROVIDER=aws make emulator-up')"
    ;;
  gcp)
    curl -fs http://localhost:4588/_localstack/health >/dev/null 2>&1 \
      && echo "floci-gcp: healthy (http://localhost:4588)" \
      || echo "floci-gcp: not reachable (run 'PROVIDER=gcp make emulator-up')"
    ;;
  azure)
    curl -fs http://localhost:4577/_localstack/health >/dev/null 2>&1 \
      && echo "floci-az: healthy (http://localhost:4577)" \
      || echo "floci-az: not reachable (run 'PROVIDER=azure make emulator-up')"
    ;;
  *)
    echo "Unknown PROVIDER='$PROVIDER'" >&2
    ;;
esac

echo ""
echo "=== Terraform stages ==="
for stage in "terraform/providers/${PROVIDER}" "terraform/platform" "terraform/tenants/${TENANT}"; do
  if [ -d "$stage" ] && [ -d "$stage/.terraform" ]; then
    echo "-- $stage --"
    (cd "$stage" && tofu output 2>/dev/null) || echo "(no outputs yet -- not applied)"
  else
    echo "-- $stage -- not initialized (tofu init hasn't been run here yet)"
  fi
  echo ""
done

echo "=== Pods ==="
kubectl get pods -A 2>/dev/null || echo "(no cluster reachable -- check KUBECONFIG, or the kubeconfig_path this provider module wrote out)"

cat <<EOF

=== UI access (run these in separate terminals, then open the URL locally or via an SSH -L tunnel) ===

Trino UI (tenant: ${TENANT}):
  kubectl port-forward -n ${TENANT} svc/trino 8080:8080
  -> http://localhost:8080

Kestra UI (shared, platform namespace):
  kubectl port-forward -n platform svc/kestra 8081:8080
  -> http://localhost:8081

Grafana (shared, observability namespace -- ${TENANT}'s dashboards are
auto-discovered from its own folder via the sidecar, see helm-values/kube-prometheus-stack-values.yaml):
  kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
  -> http://localhost:3000  (admin / admin)

MinIO console (tenant: ${TENANT}):
  kubectl port-forward -n ${TENANT} svc/minio-console 9001:9001
  -> http://localhost:9001  (minioadmin / minioadmin)

If you're SSHing in from your laptop, tunnel these through the same SSH
session instead of running a browser on the box, e.g.:
  ssh -L 8080:localhost:8080 -L 3000:localhost:3000 <user>@<box>
then run the port-forward commands above on the box itself.
EOF
