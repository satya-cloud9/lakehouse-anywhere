variable "host" {
  description = "IP or hostname of the machine to install k3s onto (e.g. your mini PC's LAN IP)."
  type        = string
}

variable "ssh_user" {
  description = "SSH user with sudo on the target machine."
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path to the private key used to SSH into the machine."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "k3s_version" {
  description = "k3s channel/version, e.g. v1.30.4+k3s1. Leave blank for k3s's own 'stable' channel."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name used for the kubeconfig context this module writes."
  type        = string
  default     = "lakehouse-baremetal"
}
