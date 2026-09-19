resource "google_container_cluster" "lakehouse" {
  name     = var.cluster_name
  location = var.gcp_region
  # Defaults to true in this provider version, specifically to stop an
  # accidental `tofu destroy` from deleting a real cluster. This module only
  # ever targets floci-gcp's local emulation, meant to be created and torn
  # down repeatedly -- leaving the real default on here just means every
  # teardown needs a manual override. If this module is ever pointed at a
  # real GKE project, reconsider this deliberately rather than leaving it off.
  deletion_protection = false

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
 # Real GKE always populates a node pool's `management` block (auto_repair/
  # auto_upgrade) on read, and this provider version (5.45.2) dereferences it
  # unconditionally in flattenNodePool -- resource_container_node_pool.go:1200
  # -- with no nil-check, unlike every other optional field in that function.
  # Confirmed via source inspection: floci-gcp's node pool response omits
  # "management" entirely when we never set it explicitly, which is exactly
  # what triggers the crash. Setting it here so there's something for
  # floci-gcp's 0.9.0 round-trip passthrough (floci-io/floci-gcp#96) to
  # actually echo back.
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
