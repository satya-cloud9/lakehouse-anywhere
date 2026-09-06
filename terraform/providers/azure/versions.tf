terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Contract-test double against floci-az (https://floci.io/az/, port 4577).
# Flagged more strongly than providers/gcp: azurerm doesn't offer the AWS
# provider's simple per-service `endpoints {}` override block, so pointing
# it at a local emulator normally means either the ARM_* environment
# variables below, or a custom `environment` block (the mechanism Azure
# Stack Hub users rely on) -- check floci-az's own setup docs for which one
# it expects before your first `tofu apply`; this is the least-verified
# provider module in this repo for exactly that reason.
#
# Expected environment variables (export before running):
#   ARM_CLIENT_ID=test
#   ARM_CLIENT_SECRET=test
#   ARM_TENANT_ID=test
#   ARM_SUBSCRIPTION_ID=test
#   ARM_ENDPOINT=http://localhost:4577   # confirm this is the variable floci-az actually reads
provider "azurerm" {
  features {}
  skip_provider_registration = true
}
