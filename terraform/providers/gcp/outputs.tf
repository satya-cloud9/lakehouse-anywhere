# See terraform/providers/CONTRACT.md. The kubeconfig here is built directly
# from the google_container_cluster resource's own attributes rather than
# shelling out to `gcloud container clusters get-credentials`, since it's
# unconfirmed whether floci-gcp emulates the gcloud CLI's own auth flow as
# well as it emulates the underlying REST API -- confirm on your first
# `tofu apply`, and switch to a real `gcloud ... get-credentials` call here
# if floci-gcp turns out to support it directly (simpler, and closer to
# what you'd do against real GKE).

locals {
  kubeconfig_content = <<-EOT
    apiVersion: v1
    kind: Config
    clusters:
      - name: ${var.cluster_name}
        cluster:
          server: https://${google_container_cluster.lakehouse.endpoint}
          certificate-authority-data: ${google_container_cluster.lakehouse.master_auth[0].cluster_ca_certificate}
    contexts:
      - name: ${var.cluster_name}
        context:
          cluster: ${var.cluster_name}
          user: ${var.cluster_name}
    current-context: ${var.cluster_name}
    users:
      - name: ${var.cluster_name}
        user:
          token: floci-gcp-local
  EOT
}

resource "local_file" "kubeconfig" {
  content         = local.kubeconfig_content
  filename        = "${path.module}/generated/kubeconfig"
  file_permission = "0600"
}

output "kubeconfig_path" {
  value      = local_file.kubeconfig.filename
  depends_on = [local_file.kubeconfig]
}

output "node_pool_refs" {
  value = [google_container_node_pool.default.name]
}

output "workload_identity_mechanism" {
  value = "workload-identity"
}

output "storage_class_name" {
  description = "Real GKE's default is pd-balanced; unconfirmed whether floci-gcp's k3s backend pre-creates this StorageClass name or only k3s's own 'local-path' -- check `kubectl get storageclass` after your first apply."
  value       = "pd-balanced"
}

# --- GCP-specific extras ---

output "trino_gsa_email" {
  value = google_service_account.trino.email
}

output "kestra_gsa_email" {
  value = google_service_account.kestra.email
}

output "parity_bucket" {
  value = google_storage_bucket.parity.name
}
