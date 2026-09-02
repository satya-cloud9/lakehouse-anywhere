#!/usr/bin/env bash
# Phase 6: register the example flow with Kestra via its REST API, and
# trigger one execution so you can confirm the whole pipeline works.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Port-forwarding Kestra (background) ==="
kubectl port-forward -n data-plane svc/kestra 8081:8080 >/tmp/kestra-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

sleep 3
if ! curl -fs http://localhost:8081/api/v1/flows >/dev/null 2>&1; then
  echo "Kestra API not reachable at http://localhost:8081 — check 'kubectl get pods -n data-plane' and paste back the Kestra pod's status/logs."
  exit 1
fi

echo "=== Registering flow ==="
curl -fsS -X POST http://localhost:8081/api/v1/flows \
  -H "Content-Type: application/x-yaml" \
  --data-binary @kestra/flows/ingest-to-iceberg.yaml \
  || echo "(non-2xx above may just mean the flow already exists — checking...)"

echo ""
echo "=== Triggering an execution ==="
curl -fsS -X POST http://localhost:8081/api/v1/executions/lakehouse/ingest-to-iceberg \
  | jq . || echo "Check the Kestra UI (make status has the port-forward command) to trigger it manually instead."

echo ""
echo "Open the Kestra UI to watch the execution: kubectl port-forward -n data-plane svc/kestra 8081:8080, then http://localhost:8081"
