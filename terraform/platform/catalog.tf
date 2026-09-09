# Nessie as the shared Iceberg REST catalog -- the multi-provider-correct
# choice over Glue (see the "Cross-tenant data sharing" and topology
# sections of the tenancy-architecture reference page): one service, one
# per cluster, speaking the standard Iceberg REST API regardless of which
# provider produced this cluster. Backed by its own small Postgres so
# catalog metadata survives a pod restart -- Nessie's in-memory default
# store does not.
#
# CHART SCHEMA CAVEAT (same as helm-values/kestra-values.yaml): written
# from Nessie's documented Helm values shape
# (https://charts.projectnessie.org), not verified against a live `helm
# install`. Run `helm show values nessie/nessie` first and reconcile any
# drifted keys before applying -- `versionStoreType`/`postgres.jdbcUrl` are
# the ones most likely to have moved.

resource "kubernetes_secret_v1" "nessie_postgres" {
  metadata {
    name      = "nessie-postgres"
    namespace = var.platform_namespace
  }
  data = {
    POSTGRES_USER     = "nessie"
    POSTGRES_PASSWORD = "nessie" # local-only demo credential -- do not reuse anywhere real
    POSTGRES_DB       = "nessie"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "nessie_postgres" {
  metadata {
    name      = "nessie-postgres-data"
    namespace = var.platform_namespace
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = { storage = "5Gi" }
    }
  }
}

resource "kubernetes_deployment_v1" "nessie_postgres" {
  metadata {
    name      = "nessie-postgres"
    namespace = var.platform_namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "nessie-postgres" }
    }
    template {
      metadata {
        labels = { app = "nessie-postgres" }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:16-alpine"
          env_from {
            secret_ref { name = kubernetes_secret_v1.nessie_postgres.metadata[0].name }
          }
          port { container_port = 5432 }
          resources {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { cpu = "500m", memory = "1Gi" }
          }
          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "pgdata"
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.nessie_postgres.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nessie_postgres" {
  metadata {
    name      = "nessie-postgres"
    namespace = var.platform_namespace
  }
  spec {
    selector = { app = "nessie-postgres" }
    port {
      port        = 5432
      target_port = 5432
    }
  }
}

resource "helm_release" "nessie" {
  name       = "nessie"
  repository = "https://charts.projectnessie.org"
  chart      = "nessie"
  namespace  = var.platform_namespace

  values = [
    yamlencode({
      versionStoreType = "JDBC2"
      jdbc = {
        jdbcUrl = "jdbc:postgresql://nessie-postgres.${var.platform_namespace}.svc.cluster.local:5432/nessie"
        secret = {
          name     = kubernetes_secret_v1.nessie_postgres.metadata[0].name
          username = "POSTGRES_USER"
          password = "POSTGRES_PASSWORD"
        }
      }
      service = {
        type = "ClusterIP"
        port = 19120
      }
    })
  ]

  depends_on = [kubernetes_service_v1.nessie_postgres]
}
