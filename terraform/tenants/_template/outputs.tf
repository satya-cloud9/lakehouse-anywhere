output "namespace" {
  value = kubernetes_namespace_v1.tenant.metadata[0].name
}

output "trino_service" {
  value = "trino.${kubernetes_namespace_v1.tenant.metadata[0].name}.svc.cluster.local"
}

output "minio_service" {
  value = "minio.${kubernetes_namespace_v1.tenant.metadata[0].name}.svc.cluster.local:9000"
}
