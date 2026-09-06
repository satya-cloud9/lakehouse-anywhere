# The first, and today only, tenant instantiation. A second tenant is
# another file like this one -- copy it, change tenant_id, done; it is
# NOT a copy of terraform/tenants/_template itself.

module "tenant_a" {
  source = "../_template"

  tenant_id                        = "tenant-a"
  isolation_tier                   = var.isolation_tier
  storage_class_name               = var.storage_class_name
  workload_identity_mechanism      = var.workload_identity_mechanism
  catalog_uri                      = var.catalog_uri
  tenant_pool_postgres_host         = var.tenant_pool_postgres_host
  tenant_pool_postgres_admin_secret = var.tenant_pool_postgres_admin_secret
  platform_namespace                = var.platform_namespace
  observability_namespace           = var.observability_namespace
}
