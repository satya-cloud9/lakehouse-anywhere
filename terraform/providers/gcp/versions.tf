terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Contract-test double against floci-gcp (https://floci.io/gcp/), the same
# family as floci (AWS) and floci-az. floci-gcp documents its GKE emulation
# as backed by a real local k3s cluster (not just faked API responses), so
# unlike providers/aws this module does NOT also run `kind` itself -- it
# reads the kubeconfig floci-gcp hands back from the google_container_cluster
# resource below. That retrieval mechanism (exactly which attribute/endpoint
# to read) isn't spelled out in floci-gcp's docs as of this writing --
# confirm it empirically on your first `tofu apply` and adjust
# `local.kubeconfig_source` in outputs.tf if needed; the resource
# definitions themselves follow the real Google provider's documented
# schema and shouldn't need to change.
provider "google" {
  project = var.gcp_project
  region  = var.gcp_region

  container_custom_endpoint = var.gcp_emulator_endpoint
  iam_custom_endpoint       = var.gcp_emulator_endpoint
  storage_custom_endpoint   = var.gcp_emulator_endpoint
}
