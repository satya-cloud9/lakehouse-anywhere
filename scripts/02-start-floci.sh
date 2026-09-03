#!/usr/bin/env bash
# Phase 2: start floci (the AWS control-plane emulator) and wait for it to
# report healthy.
#
# Originally this ran LocalStack. Switched to floci because LocalStack's
# free community image was sunset on March 23, 2026 and now requires an
# account + auth token to pull — floci is MIT-licensed with no auth token,
# ever, is wire-compatible on the same port/health-check path, and has a
# much smaller footprint (helps on our 16GB budget).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Starting floci ==="
docker compose -f docker-compose.floci.yml up -d

echo "Waiting for floci to be healthy..."
ATTEMPTS=0
MAX_ATTEMPTS=30
until curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
    echo "floci did not become healthy after $((MAX_ATTEMPTS * 3))s."
    echo "Run 'docker compose -f docker-compose.floci.yml logs' and paste the output back."
    exit 1
  fi
  sleep 3
done

echo "floci is up (started in milliseconds, not the several seconds LocalStack's JVM took). Service status:"
curl -s http://localhost:4566/_localstack/health | jq . || curl -s http://localhost:4566/_localstack/health

echo ""
echo "Next: make tf-apply"
