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

variable "additional_allowed_namespaces" {
  description = <<-EOT
    Extra namespace names allowed to send Ingress traffic into this tenant,
    on top of the tenant's own namespace + platform_namespace +
    observability_namespace + (if enabled) this tenant's own dbt execution
    namespace, which namespace.tf's NetworkPolicy always allows. Empty by
    default.

    This is the general-purpose, explicit/audited grant mechanism the
    isolation-boundary NetworkPolicy's own comment refers to ("everything
    else is the explicit, audited grant model ... not a network-level
    hole") -- for anything that isn't already covered by a first-class
    variable of its own (the dbt execution namespace has
    enable_dbt_execution_namespace below precisely so it doesn't need to
    go through this list). Set per-tenant in that tenant's own main.tf --
    never edit the shared template's NetworkPolicy resource directly to
    add a one-off hole.
  EOT
  type        = list(string)
  default     = []
}

variable "enable_dbt_execution_namespace" {
  description = <<-EOT
    Provisions this tenant's dedicated dbt/Kubernetes-task-runner execution
    namespace (dbt-execution.tf): a separate "<tenant_id>-dbt-exec"
    namespace, its own (smaller) ResourceQuota/LimitRange sized for
    transient task Pods rather than persistent services, a Role +
    RoleBinding granting ONLY kestra_service_account_name Pod-scoped
    access there, and an automatic NetworkPolicy ingress hole letting that
    one execution namespace (and nothing else) reach this tenant's own
    services.

    Defaults to true -- every tenant that wants Kestra-orchestrated
    pipelines (kestra-plugins/plugin-dbt-k8s-runner's KubernetesTaskRunner)
    needs one of these, and the whole point of the "who owns the pipeline"
    design (see the lakehouse-series article) is that execution never
    happens inside either the platform's own Kestra pod or the tenant's
    own owned-resources namespace -- only here.

    Deliberately its own namespace per tenant, not one shared execution
    namespace for every tenant: the NetworkPolicy grant this creates is
    namespace-wide, not per-Pod, so sharing one execution namespace across
    tenants would let any tenant's task Pods reach every tenant that had
    granted that shared namespace access.
  EOT
  type        = bool
  default     = true
}

variable "kestra_service_account_name" {
  description = "From terraform/platform's kestra_service_account_name output -- the real identity Kestra's own worker runs as, read from the cluster rather than assumed. Only used when enable_dbt_execution_namespace is true."
  type        = string
  default     = ""
}
