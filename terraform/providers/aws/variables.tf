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
  description = "S3 bucket name. Originally a parity-only resource (validates the HCL against AWS's real API shape); now the real, shared object store every tenant's Iceberg data lives in -- see s3.tf and CONTRACT.md's object-storage outputs."
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

variable "aws_emulator_pod_endpoint" {
  description = <<-EOT
    UNVERIFIED -- check this on first apply rather than trusting the
    default. var.aws_emulator_endpoint (http://localhost:4566) is what
    THIS Terraform process uses to create the S3 bucket, running on the
    host. Pods running inside the kind cluster are separate Docker
    containers, typically on a different Docker network than floci's
    compose network, so "localhost" from inside a pod does not reach the
    host's floci container the way it does from the host's own shell.
    172.17.0.1 is Linux Docker's default bridge gateway IP, which often
    (not always -- depends on your Docker network config) lets a
    container reach a service published on the host. Confirm with a
    quick pod-level curl against this value before trusting Nessie/Trino
    to reach it; if it's wrong, floci and kind may need to share an
    explicit Docker network instead.
  EOT
  type        = string
  default     = "http://172.17.0.1:4566"
}
