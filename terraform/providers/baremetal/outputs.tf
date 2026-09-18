# See terraform/providers/CONTRACT.md -- these outputs (the original four,
# plus the object-storage group added below) are the only things
# terraform/platform and terraform/tenants are allowed to depend on.

output "kubeconfig_path" {
  description = "Local path to the kubeconfig fetched back from the k3s install."
  # abspath() matters here, not just tidiness: this value gets captured
  # into terraform/generated/baremetal.tfvars.json and fed into
  # terraform/platform/tenants, which `tofu apply` from a *different*
  # working directory. A bare "${path.module}/..." is relative to
  # wherever THIS apply ran from -- portable only within this one
  # invocation. abspath() resolves it once, here, so it still points at
  # the right file no matter which directory later applies run from.
  value      = abspath("${path.module}/generated/kubeconfig")
  depends_on = [null_resource.fetch_kubeconfig]
}

output "node_pool_refs" {
  description = "Single-node today -- append here the day a second mini PC (or any additional node) joins this cluster."
  value       = [var.host]
}

output "workload_identity_mechanism" {
  description = "No IRSA/Workload-Identity-federation equivalent exists on bare metal -- pods authenticate to MinIO with a static, per-tenant Kubernetes Secret instead."
  value       = "static-secret"
}

output "storage_class_name" {
  description = "k3s's built-in default StorageClass, backed by Rancher's local-path-provisioner against the node's own disk (your 1TB NVMe)."
  value       = "local-path"
}

# --- Object storage (storage.tf) -- see CONTRACT.md ---

output "object_storage_endpoint" {
  description = "MinIO running as a plain Docker container on the host itself (storage.tf) -- reached over the host's own network, the same shape as reaching a real cloud's object storage from inside a cluster, not in-cluster Kubernetes DNS."
  value       = "http://${local.object_storage_advertise_host}:${var.object_storage_port}"
  depends_on  = [null_resource.object_storage]
}

output "object_storage_bucket" {
  value = var.object_storage_bucket
}

output "object_storage_access_key_id" {
  value     = var.object_storage_root_user
  sensitive = true
}

output "object_storage_secret_access_key" {
  value     = var.object_storage_root_password
  sensitive = true
}
# NOT part of CONTRACT.md's object-storage outputs group -- platform/tenants
# have no legitimate reason to read a human-facing console URL, this exists
# purely for scripts/status.sh (and you) to print. Bare-metal-specific for
# the same reason: a real cloud's object storage has its own provider
# console, unrelated to this repo's outputs, so no other provider module
# needs an equivalent.
output "object_storage_console_endpoint" {
  description = "MinIO's web console (storage.tf publishes var.object_storage_console_port -> the container's :9001). Reachable from wherever can already SSH to var.host -- tunnel it there if you're not on the box itself, e.g. ssh -L 9001:localhost:9001 <ssh_user>@<host>, then open http://localhost:9001."
  value       = "http://${var.host}:${var.object_storage_console_port}"
  depends_on  = [null_resource.object_storage]
}
