# Parity resource, same role as providers/aws/s3.tf and providers/gcp/storage.tf.
# Real data still lives in MinIO, deployed by terraform/platform.
# Storage account names must be lowercase alphanumeric only, no hyphens --
# hence the `replace()` rather than reusing var.project_name directly.

resource "azurerm_storage_account" "parity" {
  name                     = lower(replace("${var.project_name}azparity", "-", ""))
  resource_group_name     = azurerm_resource_group.lakehouse.name
  location                 = azurerm_resource_group.lakehouse.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "parity" {
  name                  = "iceberg-warehouse"
  storage_account_name  = azurerm_storage_account.parity.name
  container_access_type = "private"
}
