# Parity resource, same role as providers/aws/s3.tf -- validates the HCL
# against GCP's real API shape. Real data still lives in MinIO, deployed
# by terraform/platform.

resource "google_storage_bucket" "parity" {
  name     = "${var.project_name}-gcp-parity"
  location = var.gcp_region

  uniform_bucket_level_access = true
  force_destroy                = true

  versioning {
    enabled = true
  }
}
