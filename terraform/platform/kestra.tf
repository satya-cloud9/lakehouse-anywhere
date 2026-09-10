# Kestra, standalone for now -- see the tenancy-architecture reference
# page's "Reading the diagram" section: the Controller/Worker-Group split
# (Kestra 2.0) exists to let workers live in a different cluster/region
# from the scheduler. On a single bare-metal box that's solving a problem
# you don't have yet, so this stays standalone (server + worker together)
# until the day a second provider/cluster is actually added -- at which
# point this becomes a Controller here plus a Worker Group per cluster,
# a deployment-topology change, not a flow-authoring one.

resource "kubernetes_secret_v1" "kestra_postgres" {
  metadata {
    name      = "kestra-postgres"
    namespace = var.platform_namespace
  }
  data = {
    POSTGRES_USER     = "kestra"
    POSTGRES_PASSWORD = "kestra" # local-only demo credential -- do not reuse anywhere real
    POSTGRES_DB       = "kestra"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "kestra_postgres" {
  wait_until_bound = false

  metadata {
    name      = "kestra-postgres-data"
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

resource "kubernetes_deployment_v1" "kestra_postgres" {
  metadata {
    name      = "kestra-postgres"
    namespace = var.platform_namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "kestra-postgres" }
    }
    template {
      metadata {
        labels = { app = "kestra-postgres" }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:16-alpine"
          env_from {
            secret_ref { name = kubernetes_secret_v1.kestra_postgres.metadata[0].name }
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
          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "kestra"]
            }
            initial_delay_seconds = 5
            period_seconds         = 5
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.kestra_postgres.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "kestra_postgres" {
  metadata {
    name      = "kestra-postgres"
    namespace = var.platform_namespace
  }
  spec {
    selector = { app = "kestra-postgres" }
    port {
      port        = 5432
      target_port = 5432
    }
  }
}

resource "helm_release" "kestra" {
  name       = "kestra"
  repository = "https://helm.kestra.io"
  chart      = "kestra"
  namespace  = var.platform_namespace

  values = [file("${path.module}/../../helm-values/kestra-values.yaml")]

  depends_on = [kubernetes_deployment_v1.kestra_postgres, kubernetes_service_v1.kestra_postgres]
}
