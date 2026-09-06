variable "aws_region" {
  description = "Region used for all resources (floci accepts any valid AWS region name)."
  type        = string
  default     = "us-east-1"
}

variable "aws_emulator_endpoint" {
  description = "floci (AWS emulator) edge endpoint. Default assumes floci running on the same host via docker compose (PROVIDER=aws scripts/02-start-emulator.sh)."
  type        = string
  default     = "http://localhost:4566"
}

variable "project_name" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "lakehouse"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "storage_bucket_name" {
  description = "S3 bucket name created against floci purely as a parity resource (validates the HCL against AWS's real API shape). The real Iceberg warehouse data lives in MinIO, deployed by terraform/platform -- see s3.tf."
  type        = string
  default     = "lakehouse-aws-parity"
}

variable "kind_config_path" {
  description = "Path to the kind cluster config this module creates the cluster from."
  type        = string
  default     = "../../../kind/kind-config.yaml"
}

variable "cluster_name" {
  description = "Name for both the kind cluster and the kubeconfig context."
  type        = string
  default     = "lakehouse-aws"
}
