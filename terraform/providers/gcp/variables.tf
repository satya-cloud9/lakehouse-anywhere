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
