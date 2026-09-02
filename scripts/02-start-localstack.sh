#!/usr/bin/env bash
# Phase 2: start LocalStack and wait for it to report healthy.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Starting LocalStack ==="
docker compose -f docker-compose.localstack.yml up -d

echo "Waiting for LocalStack to be healthy..."
ATTEMPTS=0
MAX_ATTEMPTS=30
until curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
    echo "LocalStack did not become healthy after $((MAX_ATTEMPTS * 3))s."
    echo "Run 'docker compose -f docker-compose.localstack.yml logs' and paste the output back."
    exit 1
  fi
  sleep 3
done

echo "LocalStack is up. Service status:"
curl -s http://localhost:4566/_localstack/health | jq . || curl -s http://localhost:4566/_localstack/health

echo ""
echo "Next: make tf-apply"
