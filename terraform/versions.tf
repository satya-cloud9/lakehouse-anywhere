terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# All AWS-shaped resources in this directory are applied against LocalStack,
# not real AWS. Real-AWS credentials are never read (LocalStack accepts any
# non-empty access/secret key). To point this at real AWS later, delete the
# `endpoints` block below and supply real credentials via the usual AWS
# provider mechanisms (env vars, profile, etc.) — the resource definitions
# themselves (vpc.tf, iam.tf, glue.tf, kms.tf, s3.tf) shouldn't need to change.
provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style            = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = var.localstack_endpoint
    iam      = var.localstack_endpoint
    sts      = var.localstack_endpoint
    glue     = var.localstack_endpoint
    kms      = var.localstack_endpoint
    ec2      = var.localstack_endpoint
    cloudwatch = var.localstack_endpoint
    logs     = var.localstack_endpoint
  }
}
