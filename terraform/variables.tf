variable "aws_region" {
  description = "Region used for all resources (floci accepts any valid AWS region name)."
  type        = string
  default     = "us-east-1"
}

variable "aws_emulator_endpoint" {
  description = "floci (AWS emulator) edge endpoint. Default assumes floci running on the same host via docker compose (scripts/02-start-floci.sh)."
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

variable "iceberg_warehouse_bucket_name" {
  description = "S3 bucket name representing the Iceberg warehouse root in AWS-shaped resources. NOTE: this bucket is created against floci for parity with a real-AWS deployment; the kind cluster's Trino actually reads/writes data through MinIO (see helm-values/minio-values.yaml), not this bucket. Reconciling the two is the last step before pointing this at real AWS."
  type        = string
  default     = "lakehouse-iceberg-warehouse"
}
