#!/usr/bin/env bash
# Tears down the kind cluster and stops floci. Leaves Terraform state and
# everything in git untouched — run 'make tf-destroy' separately if you
# also want the floci-side AWS resources removed.
set -uo pipefail

cd "$(dirname "$0")/.."

echo "=== Deleting kind cluster ==="
kind delete cluster --name lakehouse 2>/dev/null || echo "(no cluster to delete)"

echo "=== Stopping floci ==="
docker compose -f docker-compose.floci.yml down

echo "Done. Terraform state (terraform/terraform.tfstate) and git history are untouched."
