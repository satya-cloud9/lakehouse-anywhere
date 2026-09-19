# GCP Workload Identity federation -- the GCP equivalent of AWS's IRSA.
# A Kubernetes ServiceAccount annotated with this GSA's email can assume
# its identity without a static key. Under floci-gcp this validates the
# resource/policy wiring, same caveat as providers/aws's IAM role: no real
# federation is actually enforced by the emulator.

resource "google_service_account" "trino" {
  account_id   = "${var.project_name}-trino"
  display_name = "Trino workload identity (lakehouse)"
}

resource "google_service_account" "kestra" {
  account_id   = "${var.project_name}-kestra"
  display_name = "Kestra workload identity (lakehouse)"
}

resource "google_storage_bucket_iam_member" "trino_data_access" {
  bucket = google_storage_bucket.parity.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.trino.email}"
}

resource "google_storage_bucket_iam_member" "kestra_data_access" {
  bucket = google_storage_bucket.parity.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.kestra.email}"
}

# --- Object storage static credential (CONTRACT.md's object-storage outputs) ---
#
# Workload Identity (the two GSAs above) is how a real GKE deployment
# would authenticate Trino/Kestra to GCS -- but that federation isn't
# wired to anything yet (same caveat as this file's own header comment).
# Until it is, object storage access needs a static credential the same
# way AWS's provider module now hands one back (see aws/iam.tf) -- but
# GCS has no direct equivalent of an IAM access-key pair. The
# access-key-ID/secret-access-key shape CONTRACT.md's object-storage
# outputs expect comes from GCS's own S3-interoperability feature
# instead: an HMAC key bound to a service account, which behaves like an
# AWS access key/secret pair against GCS's S3-compatible API surface.
# Every tenant shares this one credential today, same as AWS -- scoping
# it per tenant is the real follow-up work CONTRACT.md flags.

resource "google_service_account" "object_storage" {
  account_id   = "${var.project_name}-object-storage"
  display_name = "Object storage static credential (lakehouse)"
}

resource "google_storage_bucket_iam_member" "object_storage_data_access" {
  bucket = google_storage_bucket.parity.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.object_storage.email}"
}

resource "google_storage_hmac_key" "object_storage" {
  service_account_email = google_service_account.object_storage.email
}
