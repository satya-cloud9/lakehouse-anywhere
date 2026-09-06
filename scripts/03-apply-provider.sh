#!/usr/bin/env bash
# Phase 3: apply exactly one terraform/providers/<name> module, then
# capture its four contract outputs (see terraform/providers/CONTRACT.md)
# into terraform/generated/<name>.tfvars.json for the platform/tenant
# stages to consume. This is what actually keeps terraform/platform and
# terraform/tenants provider-agnostic in practice -- they only ever see
# these four values (plus whatever provider-specific extras the identity
# wiring needs), never the provider module itself.
#
# Usage: PROVIDER=baremetal|aws|gcp|azure bash scripts/03-apply-provider.sh
set -euo pipefail

cd "$(dirname "$0")/.."

PROVIDER="${PROVIDER:-aws}"
PROVIDER_DIR="terraform/providers/${PROVIDER}"

if [ ! -d "$PROVIDER_DIR" ]; then
  echo "No such provider module: $PROVIDER_DIR" >&2
  echo "Expected one of: baremetal, aws, gcp, azure" >&2
  exit 1
fi

if [ "$PROVIDER" = "baremetal" ] && [ ! -f "$PROVIDER_DIR/terraform.tfvars" ]; then
  echo "terraform/providers/baremetal/terraform.tfvars doesn't exist yet."
  echo "Create it with at least:"
  echo '  host = "<your mini PC'"'"'s LAN IP>"'
  echo '  ssh_user = "<your ssh user>"'
  echo "See terraform/providers/baremetal/variables.tf for every option."
  exit 1
fi

echo "=== tofu init ($PROVIDER_DIR) ==="
(cd "$PROVIDER_DIR" && tofu init -upgrade)

echo "=== tofu validate ($PROVIDER_DIR) ==="
(cd "$PROVIDER_DIR" && tofu validate)

echo "=== tofu apply ($PROVIDER_DIR) ==="
(cd "$PROVIDER_DIR" && tofu apply -auto-approve)

echo ""
echo "=== Capturing the provider contract outputs ==="
mkdir -p terraform/generated
(cd "$PROVIDER_DIR" && tofu output -json) > "terraform/generated/${PROVIDER}-outputs.json"

# The four required contract outputs, plus every provider-specific extra
# (trino_iam_role_arn, trino_gsa_email, etc.) -- terraform/platform and
# terraform/tenants only declare the variables they actually use, so
# passing extras through as a var-file is harmless. This is a plain
# var-file, not *.auto.tfvars.json -- it lives outside terraform/platform
# and terraform/tenants/<name>, so it has to be passed explicitly with
# -var-file (04/05 do this) rather than relying on Terraform's
# same-directory auto-loading.
jq 'map_values(.value)' "terraform/generated/${PROVIDER}-outputs.json" > "terraform/generated/${PROVIDER}.tfvars.json"

echo "Wrote terraform/generated/${PROVIDER}.tfvars.json:"
cat "terraform/generated/${PROVIDER}.tfvars.json"

echo ""
echo "Next: bash scripts/04-apply-platform.sh -- PROVIDER=${PROVIDER}"
