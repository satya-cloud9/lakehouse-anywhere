# Platform-level namespaces only. Tenant namespaces (tenant-<id>) are
# created by terraform/tenants, never here -- keeping that split is what
# makes "tenant provisioning" mean "apply the tenants module again", not
# "edit this file".

resource "kubernetes_namespace_v1" "platform" {
  metadata {
    name = var.platform_namespace
    labels = {
      purpose = "shared-platform-control-plane"
    }
  }
}

resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = var.observability_namespace
    labels = {
      purpose = "prometheus-grafana-loki-tempo"
    }
  }
}
