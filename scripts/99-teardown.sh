#!/usr/bin/env bash
# Tears down whichever stages have actually been applied, in reverse order
# (tenant -> platform -> provider), then stops the emulator container if
# one is running. Leaves Terraform state and everything in git untouched
# by default -- pass DESTROY=1 to actually run `tofu destroy` at each
# stage instead of just stopping the emulator/local cluster.
#
# Usage: PROVIDER=baremetal|aws|gcp|azure TENANT=tenant-a DESTROY=1 bash scripts/99-teardown.sh
set -uo pipefail

cd "$(dirname "$0")/.."

PROVIDER="${PROVIDER:-aws}"
TENANT="${TENANT:-tenant-a}"
DESTROY="${DESTROY:-0}"

if [ "$DESTROY" = "1" ]; then
  echo "DESTROY=1 -- running 'tofu destroy' at each applied stage, in reverse order."
  echo "(Ctrl-C now if that's not what you meant.)"
  echo ""

  if [ -d "terraform/tenants/${TENANT}" ]; then
    echo "=== tofu destroy (terraform/tenants/${TENANT}) ==="
    (cd "terraform/tenants/${TENANT}" && tofu destroy -auto-approve \
      -var-file="../../generated/${PROVIDER}.tfvars.json" \
      -var-file="../../generated/platform.tfvars.json") \
      || echo "(destroy failed or nothing to destroy -- continuing)"
  fi

  echo "=== tofu destroy (terraform/platform) ==="
  (cd terraform/platform && tofu destroy -auto-approve -var-file="../generated/${PROVIDER}.tfvars.json") \
    || echo "(destroy failed or nothing to destroy -- continuing)"

  echo "=== tofu destroy (terraform/providers/${PROVIDER}) ==="
  (cd "terraform/providers/${PROVIDER}" && tofu destroy -auto-approve) \
    || echo "(destroy failed or nothing to destroy -- continuing)"
else
  echo "DESTROY not set -- leaving all Terraform state alone (this only stops the"
  echo "local emulator/cluster below). Re-run with DESTROY=1 to actually tear down"
  echo "the ${PROVIDER} provider, platform, and ${TENANT} resources."
fi

echo ""
case "$PROVIDER" in
  baremetal)
    echo "PROVIDER=baremetal -- no emulator container to stop. If DESTROY=1 ran above,"
    echo "the k3s install on the remote host was also removed by the provider module's"
    echo "destroy provisioner (see terraform/providers/baremetal/main.tf)."
    ;;
  aws)
    echo "=== Stopping floci ==="
    docker compose -f docker-compose.floci.yml down 2>/dev/null || echo "(not running)"
    ;;
  gcp)
    echo "=== Stopping floci-gcp ==="
    docker compose -f docker-compose.floci-gcp.yml down 2>/dev/null || echo "(not running)"
    ;;
  azure)
    echo "=== Stopping floci-az ==="
    docker compose -f docker-compose.floci-az.yml down 2>/dev/null || echo "(not running)"
    ;;
  *)
    echo "Unknown PROVIDER='$PROVIDER' -- skipping emulator teardown." >&2
    ;;
esac

echo ""
echo "Done. Terraform state and git history are untouched unless DESTROY=1 was set."
