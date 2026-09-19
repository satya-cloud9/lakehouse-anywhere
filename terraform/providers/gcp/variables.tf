variable "gcp_project" {
  description = "Any project ID string -- floci-gcp doesn't validate it against a real GCP org."
  type        = string
  default     = "lakehouse-local"
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "gcp_emulator_endpoint" {
  description = "floci-gcp endpoint. Default assumes floci-gcp running on the same host (docker run -p 4588:4588 floci/floci-gcp:latest)."
  type        = string
  default     = "http://localhost:4588"
}

variable "project_name" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "lakehouse"
}

variable "cluster_name" {
  type    = string
  default = "lakehouse-gcp"
}

variable "node_count" {
  description = "Node count for the emulated GKE cluster's default node pool."
  type        = number
  default     = 2
}
variable "gcp_emulator_pod_endpoint" {
  description = <<-EOT
    UNVERIFIED -- check this on first apply rather than trusting the
    default. var.gcp_emulator_endpoint (http://localhost:4588) is what
    THIS Terraform process uses against floci-gcp's API, running on the
    host. Pods scheduled onto floci-gcp's own internal k3s cluster (see
    versions.tf's provider "google" comment -- this module doesn't run a
    separate kind/k3s cluster of its own, unlike providers/aws) may or
    may not share a Docker network with the floci-gcp container itself.
    172.17.0.1 is Linux Docker's default bridge gateway IP, the same
    first guess used in providers/aws/variables.tf's
    aws_emulator_pod_endpoint for that version of this same problem --
    confirm with a pod-level curl against this value before trusting
    Nessie/Trino to reach it; if floci-gcp's internal cluster turns out
    to be fully isolated from the host's Docker network, this may need
    to point at whatever address floci-gcp itself documents for
    reaching the host instead.
  EOT
  type        = string
  default     = "http://172.17.0.1:4588"
}
