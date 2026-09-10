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
resource "kubernetes_secret_v1" "nessie_minio_creds" {
   metadata {
      name = "nessie-minio-creds"
      namespace = var.platform_namespace
   }
   data = {
     awsAccessKeyId = "minioadmin"
     awsSecretAccessKey = "minioadmin"
   }
}

resource "kubernetes_persistent_volume_claim_v1" "nessie_postgres" {
  wait_until_bound = false

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
  # Pinned -- the repo index's "latest" (0.108.5) 404s on its own release
  # asset upstream (broken/retracted release, not something wrong here).
  # 0.108.4 is a known-good fallback: its image already pulled and ran
  # successfully in earlier testing.
  version    = "0.108.4"
  namespace  = var.platform_namespace

  values = [
    yamlencode({
      # CORRECTED against the chart's real current shape (projectnessie/nessie
      # helm/nessie/README.md) -- the old `postgres.jdbcUrl/username/password`
      # keys above were never a real key in this chart, so they were silently
      # ignored. That's why it failed on `secret "datasource-creds" not
      # found`: with no jdbc.secret block supplied, the chart falls back to
      # its own hardcoded default, which expects a secret literally named
      # "datasource-creds" -- something nothing here ever created. Real
      # shape is versionStoreType: JDBC2 ("JDBC" is a deprecated alias) plus
      # a jdbc.secret block naming an *existing* secret and the KEY NAMES
      # inside it holding the username/password (not literal values) -- so
      # this points at the nessie-postgres secret already created above.
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
      # Every other component in this repo pins resources -- this was the
      # one exception, meaning it ran BestEffort QoS (no CPU/memory floor,
      # first evicted under node pressure) with a footprint invisible to
      # any capacity planning. Sized as a small Quarkus/JVM REST service --
      # lighter than Kestra's Standalone process, similar order of
      # magnitude to Trino's coordinator. Adjust once you've actually
      # observed it running.
      resources = {
        requests = { cpu = "500m", memory = "768Mi" }
        limits   = { cpu = "1", memory = "1536Mi" }
      }

      # catalog.enabled defaults to FALSE in this chart -- confirmed via
      # `helm show values nessie/nessie --version 0.108.4`, not guessed --
      # and the Iceberg REST endpoint requires at least one warehouse and
      # its backing object-store location configured before ANY request
      # succeeds. This is what Trino's coordinator was actually stuck on at
      # startup (inside StaticCatalogManager.loadInitialCatalogs): not a
      # crash, just an endpoint with nothing behind it.
      #
      # Hardcoded to tenant-a for this first working cut -- Nessie is one
      # shared platform-level service, but MinIO is deployed per-tenant
      # (see terraform/tenants/_template/minio.tf), so each tenant needs
      # its OWN named warehouse pointing at ITS OWN MinIO. trino.tf already
      # anticipates this (iceberg.rest-catalog.warehouse = var.tenant_id);
      # registering warehouses dynamically per-tenant, instead of
      # statically here, is real follow-up work once a second tenant
      # exists.
      catalog = {
        enabled = true
        iceberg = {
          defaultWarehouse = "tenant-a"
          warehouses = [
            {
              name     = "tenant-a"
              location = "s3://warehouse/"
            }
          ]
        }
        storage = {
          s3 = {
            defaultOptions = {
              endpoint        = "http://minio.tenant-a.svc.cluster.local:9000"
              pathStyleAccess = true
              authType        = "STATIC"
              accessKeySecret = {
                name               = kubernetes_secret_v1.nessie_minio_creds.metadata[0].name
                awsAccessKeyId     = "awsAccessKeyId"
                awsSecretAccessKey = "awsSecretAccessKey"
              }
            }
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_deployment_v1.nessie_postgres,
    kubernetes_service_v1.nessie_postgres,
  ]
}
