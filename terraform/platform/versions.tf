terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

# Configured entirely from the provider contract (see
# terraform/providers/CONTRACT.md) -- this file has no idea which of
# providers/{baremetal,aws,gcp,azure} produced var.kubeconfig_path, and
# that's the point. Feed it whichever provider's kubeconfig_path output
# you applied (scripts/03-apply-provider.sh captures this into
# terraform/generated/<provider>.tfvars.json for you).

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}
