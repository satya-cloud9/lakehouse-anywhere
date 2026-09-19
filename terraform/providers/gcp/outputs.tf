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
  filename        = abspath("${path.module}/generated/kubeconfig")
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
  description = "Real GKE's default is pd-balanced, but confirmed via kubectl get storageclass against this module's first real apply: floci-gcp's k3s backend only provides k3s's own built-in 'local-path' (rancher.io/local-path), same as providers/baremetal -- pd-balanced doesn't exist here, so any PVC requesting it sticks in Pending forever. Using the confirmed real value, not the real-GKE assumption, until/unless floci-gcp adds a pd-balanced-named StorageClass of its own."
  value       = "local-path"
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

# --- Object storage (CONTRACT.md's object-storage outputs) ---

output "object_storage_endpoint" {
  description = "See variables.tf's gcp_emulator_pod_endpoint -- UNVERIFIED, confirm pod-reachability on first apply."
  value       = var.gcp_emulator_pod_endpoint
}

output "object_storage_bucket" {
  value = google_storage_bucket.parity.name
}

output "object_storage_access_key_id" {
  value     = google_storage_hmac_key.object_storage.access_id
  sensitive = true
}

output "object_storage_secret_access_key" {
  value     = google_storage_hmac_key.object_storage.secret
  sensitive = true
}
