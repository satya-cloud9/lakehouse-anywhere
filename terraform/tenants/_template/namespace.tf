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

# Ingress: default-deny, with explicit allows for same-namespace traffic
# and for the platform/observability namespaces (the only things that
# should ever cross this boundary uninvited -- everything else is the
# explicit, audited grant model from the "Cross-tenant data sharing"
# section, not a network-level hole).
#
# Egress is intentionally left open here -- pinning it down to exactly
# DNS + the platform namespace + this tenant's own MinIO is the more
# correct end state, but needs verifying against what Trino/Kestra/MinIO
# actually call at runtime before locking it down without breaking them.
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
  }
}
