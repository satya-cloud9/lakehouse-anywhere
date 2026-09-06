# See terraform/providers/CONTRACT.md -- these four outputs are the only
# thing terraform/platform and terraform/tenants are allowed to depend on.

output "kubeconfig_path" {
  description = "Local path to the kubeconfig fetched back from the k3s install."
  value       = "${path.module}/generated/kubeconfig"
  depends_on  = [null_resource.fetch_kubeconfig]
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
