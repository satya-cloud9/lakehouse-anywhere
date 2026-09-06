resource "azurerm_resource_group" "lakehouse" {
  name     = "${var.project_name}-rg"
  location = var.azure_location
}

resource "azurerm_kubernetes_cluster" "lakehouse" {
  name                = var.cluster_name
  location            = azurerm_resource_group.lakehouse.location
  resource_group_name  = azurerm_resource_group.lakehouse.name
  dns_prefix           = var.cluster_name

  # Azure AD Workload Identity -- the AKS equivalent of IRSA/GCP Workload
  # Identity. Requires both flags; unconfirmed whether floci-az enforces
  # the underlying OIDC issuer the way real AKS does, or just accepts the
  # resource shape (same caveat as everywhere else in this module).
  oidc_issuer_enabled      = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = "Standard_D4s_v5"
  }

  identity {
    type = "SystemAssigned"
  }
}
