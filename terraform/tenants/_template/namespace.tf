# The isolation boundary from the tenancy-architecture reference page's
# main diagram -- a namespace, a ResourceQuota, and a default-deny
# NetworkPolicy with explicit holes only for the platform and
# observability namespaces (the cross-boundary mechanisms: gRPC to the
# Kestra Controller, the Nessie catalog, the Shared OLTP Service, and
# Prometheus scraping in the other direction).

resource "kubernetes_namespace_v1" "tenant" {
  metadata {
    name = var.tenant_id
    labels = {
      "lakehouse.io/tenant"          = var.tenant_id
      "lakehouse.io/isolation-tier"  = var.isolation_tier
    }
  }
}

resource "kubernetes_resource_quota_v1" "tenant" {
  metadata {
    name      = "${var.tenant_id}-quota"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = var.isolation_tier == "pool" ? "4" : "8"
      "requests.memory" = var.isolation_tier == "pool" ? "8Gi" : "16Gi"
      "limits.cpu"      = var.isolation_tier == "pool" ? "8" : "16"
      "limits.memory"   = var.isolation_tier == "pool" ? "16Gi" : "32Gi"
    }
  }
}

resource "kubernetes_limit_range_v1" "tenant" {
  metadata {
    name      = "${var.tenant_id}-default-limits"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "tenant_isolation" {
  metadata {
    name      = "${var.tenant_id}-isolation-boundary"
    namespace = kubernetes_namespace_v1.tenant.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = kubernetes_namespace_v1.tenant.metadata[0].name
          }
        }
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.platform_namespace
          }
        }
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.observability_namespace
          }
        }
      }
    }

    dynamic "ingress" {
      for_each = var.enable_dbt_execution_namespace ? [kubernetes_namespace_v1.dbt_exec[0].metadata[0].name] : []
      content {
        from {
          namespace_selector {
            match_labels = {
              "kubernetes.io/metadata.name" = ingress.value
            }
          }
        }
      }
    }

    dynamic "ingress" {
      for_each = var.additional_allowed_namespaces
      content {
        from {
          namespace_selector {
            match_labels = {
              "kubernetes.io/metadata.name" = ingress.value
            }
          }
        }
      }
    }
  }
}
