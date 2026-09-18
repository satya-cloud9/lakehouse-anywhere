# Every one of these (except project_name) is a pass-through of a provider
# module's contract output -- see terraform/providers/CONTRACT.md. This
# module never imports a provider module directly; scripts/03-apply-provider.sh
# captures `tofu output -json` from whichever provider you applied into
# terraform/generated/<provider>.tfvars.json, and scripts/04-apply-platform.sh
# feeds it in here via -var-file, which is what actually keeps this
# directory provider-agnostic in practice, not just in principle.

variable "kubeconfig_path" {
  type = string
}

variable "storage_class_name" {
  type = string
}

variable "workload_identity_mechanism" {
  type = string
  validation {
    condition     = contains(["irsa", "workload-identity", "azuread-workload-identity", "static-secret"], var.workload_identity_mechanism)
    error_message = "Must be one of: irsa, workload-identity, azuread-workload-identity, static-secret -- see terraform/providers/CONTRACT.md."
  }
}

# --- Object storage (CONTRACT.md's object-storage outputs) ---
# What lets Nessie boot without any tenant existing -- see catalog.tf.

variable "object_storage_endpoint" {
  type = string
}

variable "object_storage_bucket" {
  type = string
}

variable "object_storage_access_key_id" {
  type      = string
  sensitive = true
}

variable "object_storage_secret_access_key" {
  type      = string
  sensitive = true
}

variable "project_name" {
  type    = string
  default = "lakehouse"
}

variable "platform_namespace" {
  type    = string
  default = "platform"
}

variable "observability_namespace" {
  type    = string
  default = "observability"
}

# Both default to true (nothing changes for a normal/mini-PC-sized apply).
# Set either to false in a local terraform/platform/terraform.tfvars
# (gitignored, same convention as terraform/providers/baremetal's) to trim
# footprint on a smaller box -- not a hack to remember to revert later,
# just don't carry that override to bigger hardware. Neither is a real
# dependency of the core Kestra -> Trino -> Iceberg/Nessie pipeline the
# example flow exercises: observability is metrics/logs/traces, and the
# Shared OLTP Service only matters once you have genuinely cross-tenant
# Postgres-resident data to protect with RLS (see shared-oltp.tf). The
# tenant-pool Postgres (tenant-pool-postgres.tf) has no such toggle --
# a pool-tier tenant's schema-creation Job (terraform/tenants/_template/
# postgres.tf) depends on it directly, so it's not optional while any
# pool-tier tenant is applied.
variable "enable_observability" {
  description = "kube-prometheus-stack + Loki + Tempo. ~1.75Gi requests / ~3.5Gi limits when on."
  type        = bool
  default     = true
}

variable "enable_shared_oltp" {
  description = "The Shared OLTP Service (shared-oltp.tf). ~512Mi requests / ~1Gi limits when on."
  type        = bool
  default     = true
}
