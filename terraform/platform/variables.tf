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
