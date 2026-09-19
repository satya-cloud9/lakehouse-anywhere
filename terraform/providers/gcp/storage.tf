# Originally a parity-only resource, same role as providers/aws/s3.tf --
# validated the HCL against GCP's real API shape and nothing more.
# Promoted here to the real, shared object store every tenant's Iceberg
# data lives in, the same way AWS's equivalent bucket was promoted in
# aws/s3.tf -- see CONTRACT.md's "object-storage outputs" section. The
# access-key/credential wiring this needed lives in iam.tf, as a GCS HMAC
# key rather than an AWS-style IAM access key -- see iam.tf's own comment
# on why GCS needs a different mechanism here.
resource "google_storage_bucket" "parity" {
  name     = "${var.project_name}-gcp-parity"
  location = var.gcp_region

  uniform_bucket_level_access = true
  force_destroy                = true

  versioning {
    enabled = true
  }
}
