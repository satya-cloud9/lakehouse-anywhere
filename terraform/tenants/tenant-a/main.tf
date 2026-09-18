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
  object_storage_endpoint          = var.object_storage_endpoint
  object_storage_access_key_id     = var.object_storage_access_key_id
  object_storage_secret_access_key = var.object_storage_secret_access_key
  tenant_pool_postgres_host         = var.tenant_pool_postgres_host
  tenant_pool_postgres_admin_secret = var.tenant_pool_postgres_admin_secret
  platform_namespace                = var.platform_namespace
  observability_namespace           = var.observability_namespace

  # dbt-execution.tf provisions tenant-a-dbt-exec automatically (default
  # enable_dbt_execution_namespace = true) -- namespace, its own
  # ResourceQuota/LimitRange, the Role/RoleBinding granting exactly the
  # real Kestra worker identity (not a hardcoded guess) Pod-scoped access
  # there, and the NetworkPolicy ingress hole letting only that namespace
  # reach tenant-a. No manual rbac/tenant-namespace-rbac.yaml apply and no
  # additional_allowed_namespaces entry needed for this anymore -- both
  # were the pre-formalization version of what this variable now does
  # declaratively, in the same `tofu apply` as everything else about this
  # tenant's workspace.
  kestra_service_account_name = var.kestra_service_account_name
}
