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
