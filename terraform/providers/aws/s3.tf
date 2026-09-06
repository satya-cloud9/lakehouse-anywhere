# S3 bucket created against floci purely as a parity resource -- see
# variables.tf's note on storage_bucket_name. The real Iceberg warehouse
# data lives in MinIO, deployed by terraform/platform, not here.

resource "aws_s3_bucket" "parity" {
  bucket = var.storage_bucket_name

  tags = {
    Name = "${var.project_name}-aws-parity"
  }
}

resource "aws_s3_bucket_versioning" "parity" {
  bucket = aws_s3_bucket.parity.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "parity" {
  bucket = aws_s3_bucket.parity.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.lakehouse.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "parity" {
  bucket = aws_s3_bucket.parity.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
