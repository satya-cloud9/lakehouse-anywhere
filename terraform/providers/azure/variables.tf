variable "azure_location" {
  type    = string
  default = "eastus"
}

variable "project_name" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "lakehouse"
}

variable "cluster_name" {
  type    = string
  default = "lakehouse-azure"
}

variable "node_count" {
  description = "Node count for the emulated AKS cluster's default node pool."
  type        = number
  default     = 2
}
