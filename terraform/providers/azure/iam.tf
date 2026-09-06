# Azure AD Workload Identity -- a user-assigned managed identity federated
# to a Kubernetes ServiceAccount via its OIDC issuer, same shape as
# providers/aws's IRSA role and providers/gcp's workload-identity GSA.

resource "azurerm_user_assigned_identity" "trino" {
  name                = "${var.project_name}-trino"
  location            = azurerm_resource_group.lakehouse.location
  resource_group_name = azurerm_resource_group.lakehouse.name
}

resource "azurerm_user_assigned_identity" "kestra" {
  name                = "${var.project_name}-kestra"
  location            = azurerm_resource_group.lakehouse.location
  resource_group_name = azurerm_resource_group.lakehouse.name
}

resource "azurerm_role_assignment" "trino_data_access" {
  scope                = azurerm_storage_account.parity.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.trino.principal_id
}

resource "azurerm_role_assignment" "kestra_data_access" {
  scope                = azurerm_storage_account.parity.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.kestra.principal_id
}
