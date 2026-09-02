#!/usr/bin/env bash
# Phase 3: apply the AWS-shaped Terraform against LocalStack.
set -euo pipefail

cd "$(dirname "$0")/../terraform"

if ! curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1; then
  echo "LocalStack doesn't look reachable at http://localhost:4566 — run 'make localstack-up' first."
  exit 1
fi

echo "=== tofu init ==="
tofu init -upgrade

echo "=== tofu validate ==="
tofu validate

echo "=== tofu plan ==="
tofu plan -out=tfplan

echo "=== tofu apply ==="
tofu apply -auto-approve tfplan

echo ""
echo "=== Outputs ==="
tofu output

echo ""
echo "Next: make kind-up"
