terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# All AWS-shaped resources in this directory are applied against floci
# (originally LocalStack — swapped because LocalStack's community image now
# requires an auth token; floci is wire-compatible on the same port, so
# nothing else here had to change). Real-AWS credentials are never read
# (floci accepts any non-empty access/secret key, same as LocalStack did).
# To point this at real AWS later, delete the `endpoints` block below and
# supply real credentials via the usual AWS provider mechanisms (env vars,
# profile, etc.) — the resource definitions themselves (vpc.tf, iam.tf,
# glue.tf, kms.tf, s3.tf) shouldn't need to change.
provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style            = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = var.aws_emulator_endpoint
    iam      = var.aws_emulator_endpoint
    sts      = var.aws_emulator_endpoint
    glue     = var.aws_emulator_endpoint
    kms      = var.aws_emulator_endpoint
    ec2      = var.aws_emulator_endpoint
    cloudwatch = var.aws_emulator_endpoint
    logs     = var.aws_emulator_endpoint
  }
}
