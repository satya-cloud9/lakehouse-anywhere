variable "kubeconfig_path" {
  type = string
}

variable "storage_class_name" {
  type = string
}

variable "workload_identity_mechanism" {
  type = string
}

variable "catalog_uri" {
  type = string
}

variable "tenant_pool_postgres_host" {
  type    = string
  default = ""
}

variable "tenant_pool_postgres_admin_secret" {
  type    = string
  default = ""
}

variable "platform_namespace" {
  type    = string
  default = "platform"
}

variable "observability_namespace" {
  type    = string
  default = "observability"
}

variable "isolation_tier" {
  description = "Only \"pool\" is meaningful on a single-node cluster -- see terraform/tenants/_template/variables.tf."
  type        = string
  default     = "pool"
}

variable "kestra_service_account_name" {
  description = "From terraform/platform's kestra_service_account_name output -- passed through to the _template module's dbt-execution.tf RoleBinding."
  type        = string
}
