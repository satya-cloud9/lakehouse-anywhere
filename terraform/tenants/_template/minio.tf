resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  namespace  = kubernetes_namespace_v1.tenant.metadata[0].name

  values = [file("${path.module}/../../../helm-values/minio-values.yaml")]

  set {
    name  = "buckets[0].name"
    value = "warehouse"
  }
}
