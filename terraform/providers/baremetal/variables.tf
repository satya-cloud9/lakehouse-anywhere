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

# --- Shared object storage (storage.tf) ---
# Runs as a plain Docker container on the host, not a Kubernetes workload
# -- see storage.tf and versions.tf for why.

variable "object_storage_container_name" {
  type    = string
  default = "lakehouse-object-storage"
}

variable "object_storage_port" {
  description = "Host port MinIO's API is published on (docker run -p). Pods reach this at http://<var.host>:<this port>, the same way they'd reach a real cloud's object storage over the network -- not in-cluster DNS."
  type        = number
  default     = 9000
}

variable "object_storage_data_dir" {
  description = "Directory on the host (not inside any container) MinIO's data is bind-mounted from. Persists across container recreation; you own backing it up, same as k3s's own local-path volumes."
  type        = string
  default     = "/opt/lakehouse/object-storage"
}

variable "object_storage_bucket" {
  type    = string
  default = "warehouse"
}

variable "object_storage_console_port" {
  description = "Host port MinIO's web console is published on (docker run -p). The container is already started with --console-address :9001 (storage.tf), but that alone doesn't make it reachable from outside the container -- needs its own -p mapping, same as the API port does."
  type        = number
  default     = 9001
}
variable "object_storage_root_user" {
  description = "Same local-only demo credential pattern already used elsewhere in this repo -- not a real secrets-management story, just no worse than the status quo it replaces."
  type        = string
  default     = "minioadmin"
}

variable "object_storage_root_password" {
  type      = string
  default   = "minioadmin"
  sensitive = true
}
variable "object_storage_advertise_host" {
  description = "Address pods use to reach the object_storage container's published port. Almost always the same as var.host, EXCEPT when var.host is something like \"127.0.0.1\" or \"localhost\" -- a valid SSH target when tofu apply runs on the box itself (that's why k3s_install/fetch_kubeconfig/object_storage never surfaced this), but meaningless from inside a pod's own network namespace, which does not share the host's loopback. Confirmed live: with host left at 127.0.0.1, Nessie's ObjectStoresHealthCheck ended up hitting its own container's internal port 9000 (nessie-mgmt) instead of MinIO, and a bare 404 from that got misread by the S3 SDK as NoSuchBucketException. Leave blank (the default) to fall back to var.host; set this explicitly to the box's real LAN IP if var.host isn't one."
  type        = string
  default     = ""
}
