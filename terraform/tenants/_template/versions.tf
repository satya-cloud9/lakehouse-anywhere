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

# No provider blocks here on purpose -- this is a child module, not a root.
# It inherits the kubernetes/helm provider configuration from whichever
# root module calls it (see ../tenant-a/main.tf).
