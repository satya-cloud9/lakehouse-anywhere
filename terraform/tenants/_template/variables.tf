# Instantiated once per tenant (see ../tenant-a/main.tf) -- adding a
# tenant, or moving one to a different isolation tier, means another
# module call with different values here, never a copy of this directory.

variable "tenant_id" {
  description = "Short, DNS-safe identifier, e.g. \"tenant-a\". Used as the namespace name and the Nessie/schema namespace."
  type        = string
}

variable "isolation_tier" {
  description = "pool | node_group | dedicated -- see the tenancy-architecture reference page's \"Isolation tiers\" section. Only pool is meaningful on a single-node cluster; node_group/dedicated need real additional node capacity to mean anything physically."
  type        = string
  default     = "pool"

  validation {
    condition     = contains(["pool", "node_group", "dedicated"], var.isolation_tier)
    error_message = "isolation_tier must be one of: pool, node_group, dedicated."
  }
}

variable "storage_class_name" {
  description = "Pass-through of the provider contract's storage_class_name (see terraform/providers/CONTRACT.md)."
  type        = string
}

variable "workload_identity_mechanism" {
  description = "Pass-through of the provider contract's workload_identity_mechanism."
  type        = string
}

# --- from terraform/platform's outputs ---

variable "catalog_uri" {
  description = "Nessie's Iceberg REST catalog endpoint, from terraform/platform's catalog_uri output."
  type        = string
}

variable "tenant_pool_postgres_host" {
  description = "Only used when isolation_tier = \"pool\". From terraform/platform's tenant_pool_postgres_host output."
  type        = string
  default     = ""
}

variable "tenant_pool_postgres_admin_secret" {
  description = "Only used when isolation_tier = \"pool\". From terraform/platform's tenant_pool_postgres_admin_secret output. Must exist in var.platform_namespace."
  type        = string
  default     = ""
}

variable "platform_namespace" {
  type    = string
  default = "platform"
}

variable "observability_namespace" {
  type    = string
  default = "observability"
}
