terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.9"
    }
  }
}

# All AWS-shaped resources in this directory are applied against floci, and
# are a contract-test double, not a real cluster provisioner -- see
# terraform/providers/CONTRACT.md and docs/architecture.md for why this
# repo asks floci for VPC/IAM/KMS/S3 (to validate the HCL against AWS's
# real API shape) but still uses `kind` directly for the cluster itself,
# rather than floci's own EKS emulation. Real-AWS credentials are never
# read (floci accepts any non-empty access/secret key). To point this at
# real AWS later: delete the `endpoints` block below, supply real
# credentials via the usual AWS provider mechanisms, and replace the
# `kind_cluster` resource in cluster.tf with a real `aws_eks_cluster` +
# managed node group.
provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style            = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3         = var.aws_emulator_endpoint
    iam        = var.aws_emulator_endpoint
    sts        = var.aws_emulator_endpoint
    kms        = var.aws_emulator_endpoint
    ec2        = var.aws_emulator_endpoint
    cloudwatch = var.aws_emulator_endpoint
    logs       = var.aws_emulator_endpoint
  }
}
