# See terraform/providers/CONTRACT.md. Unlike providers/gcp, AKS's own
# resource attribute (kube_config_raw) hands back a complete kubeconfig
# directly -- no manual templating needed here, assuming floci-az populates
# that attribute the same way real AKS does (verify on first apply).

resource "local_file" "kubeconfig" {
  content         = azurerm_kubernetes_cluster.lakehouse.kube_config_raw
  filename        = "${path.module}/generated/kubeconfig"
  file_permission = "0600"
}

output "kubeconfig_path" {
  value      = local_file.kubeconfig.filename
  depends_on = [local_file.kubeconfig]
}

output "node_pool_refs" {
  value = [azurerm_kubernetes_cluster.lakehouse.default_node_pool[0].name]
}

output "workload_identity_mechanism" {
  value = "azuread-workload-identity"
}

output "storage_class_name" {
  description = "Real AKS's default is managed-csi; unconfirmed whether floci-az's cluster backend pre-creates this name -- check `kubectl get storageclass` after your first apply."
  value       = "managed-csi"
}

# --- Azure-specific extras ---

output "trino_identity_client_id" {
  value = azurerm_user_assigned_identity.trino.client_id
}

output "kestra_identity_client_id" {
  value = azurerm_user_assigned_identity.kestra.client_id
}

output "parity_storage_account" {
  value = azurerm_storage_account.parity.name
}
