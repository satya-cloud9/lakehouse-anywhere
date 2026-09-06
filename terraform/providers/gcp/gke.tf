resource "google_container_cluster" "lakehouse" {
  name     = var.cluster_name
  location = var.gcp_region

  # Real GKE wants the default node pool removed in favor of a managed one
  # below; keeping that shape here even though floci-gcp's own node
  # management may not need it, so this diffs minimally against a real-GCP
  # version later.
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.gcp_project}.svc.id.goog"
  }
}

resource "google_container_node_pool" "default" {
  name       = "${var.cluster_name}-pool"
  location   = var.gcp_region
  cluster    = google_container_cluster.lakehouse.name
  node_count = var.node_count

  node_config {
    machine_type = "e2-standard-4"

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
