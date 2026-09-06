terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# No cloud provider block here on purpose -- this module's only job is to
# turn an already-existing machine into a Kubernetes cluster over SSH.
# There is nothing to authenticate to except the box itself.
