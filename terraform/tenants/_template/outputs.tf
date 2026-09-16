output "namespace" {
  value = kubernetes_namespace_v1.tenant.metadata[0].name
}

output "trino_service" {
  value = "trino.${kubernetes_namespace_v1.tenant.metadata[0].name}.svc.cluster.local"
}

output "minio_service" {
  value = "minio.${kubernetes_namespace_v1.tenant.metadata[0].name}.svc.cluster.local:9000"
}

output "dbt_execution_namespace" {
  description = "This tenant's dbt/Kubernetes-task-runner execution namespace name (dbt-execution.tf) -- null when enable_dbt_execution_namespace is false. Flow authors point KubernetesTaskRunner's own `namespace` field at this value."
  value       = var.enable_dbt_execution_namespace ? kubernetes_namespace_v1.dbt_exec[0].metadata[0].name : null
}
