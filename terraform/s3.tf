# S3 bucket representing the Iceberg warehouse root in AWS-shaped resources.
# Created against floci for parity with what you'd apply against real
# AWS. IMPORTANT: the local Trino/kind stack actually reads and writes
# through MinIO (helm-values/minio-values.yaml), not this bucket — see the
# note on var.iceberg_warehouse_bucket_name. Reconciling the two (pointing
# Trino at this bucket instead of MinIO) is the step for moving to real AWS.

resource "aws_s3_bucket" "iceberg_warehouse" {
  bucket = var.iceberg_warehouse_bucket_name

  tags = {
    Name = "${var.project_name}-iceberg-warehouse"
  }
}

resource "aws_s3_bucket_versioning" "iceberg_warehouse" {
  bucket = aws_s3_bucket.iceberg_warehouse.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iceberg_warehouse" {
  bucket = aws_s3_bucket.iceberg_warehouse.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.lakehouse.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "iceberg_warehouse" {
  bucket = aws_s3_bucket.iceberg_warehouse.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
