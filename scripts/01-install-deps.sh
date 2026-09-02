#!/usr/bin/env bash
# Phase 1: install Docker, kind, kubectl, helm, OpenTofu, and awscli-local.
# Written for Ubuntu 22.04 (apt-based). Idempotent — safe to re-run.
set -euo pipefail

echo "=== Installing base packages ==="
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release jq unzip apt-transport-https software-properties-common python3-pip

# --- Docker Engine (official convenience script) ---
if ! command -v docker >/dev/null 2>&1; then
  echo "=== Installing Docker Engine ==="
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  sudo usermod -aG docker "$USER"
  echo "Added $USER to the docker group — you'll need to log out/in (or run 'newgrp docker') for this to take effect without sudo."
else
  echo "Docker already installed: $(docker --version)"
fi

sudo systemctl enable docker >/dev/null 2>&1 || true
sudo systemctl start docker >/dev/null 2>&1 || true

# Docker Compose plugin (usually bundled by get-docker.sh, but double-check)
if ! docker compose version >/dev/null 2>&1; then
  echo "=== Installing docker-compose-plugin ==="
  sudo apt-get install -y docker-compose-plugin
fi

# --- kind ---
if ! command -v kind >/dev/null 2>&1; then
  echo "=== Installing kind ==="
  KIND_VERSION=$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r .tag_name 2>/dev/null || echo "")
  if [ -z "$KIND_VERSION" ] || [ "$KIND_VERSION" = "null" ]; then
    KIND_VERSION="v0.27.0"  # fallback pin — update if this is stale
    echo "Could not resolve latest kind release, falling back to $KIND_VERSION"
  fi
  curl -Lo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
  chmod +x /tmp/kind
  sudo mv /tmp/kind /usr/local/bin/kind
  echo "Installed kind $KIND_VERSION"
else
  echo "kind already installed: $(kind version)"
fi

# --- kubectl ---
if ! command -v kubectl >/dev/null 2>&1; then
  echo "=== Installing kubectl ==="
  KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  curl -Lo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /tmp/kubectl
  sudo mv /tmp/kubectl /usr/local/bin/kubectl
  echo "Installed kubectl $KUBECTL_VERSION"
else
  echo "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

# --- helm ---
if ! command -v helm >/dev/null 2>&1; then
  echo "=== Installing helm ==="
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm.sh
  chmod +x /tmp/get-helm.sh
  /tmp/get-helm.sh
else
  echo "helm already installed: $(helm version --short)"
fi

# --- OpenTofu (Terraform-compatible, MPL-licensed) ---
if ! command -v tofu >/dev/null 2>&1; then
  echo "=== Installing OpenTofu ==="
  curl -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/install-opentofu.sh
  chmod +x /tmp/install-opentofu.sh
  sudo /tmp/install-opentofu.sh --install-method deb
else
  echo "OpenTofu already installed: $(tofu version)"
fi

# --- awslocal (awscli-local) — thin wrapper for ad-hoc `aws` calls against LocalStack ---
pip3 install --quiet --break-system-packages awscli-local awscli 2>&1 | tail -5 || \
  pip3 install --quiet --user awscli-local awscli 2>&1 | tail -5

echo ""
echo "=== Versions ==="
docker --version || true
docker compose version || true
kind version || true
kubectl version --client 2>/dev/null || true
helm version --short || true
tofu version || true
awslocal --version 2>/dev/null || echo "awslocal: check 'pip3 show awscli-local' if this didn't print"

echo ""
echo "If this is the first install of Docker, run 'newgrp docker' (or log out/in) before continuing to 'make localstack-up'."
