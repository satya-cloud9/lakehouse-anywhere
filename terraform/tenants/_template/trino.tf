# The Iceberg catalog config is generated here (not in helm-values/trino-values.yaml)
# because it needs this tenant's own namespace and MinIO endpoint
# interpolated in -- catalog.type=rest points at Nessie (terraform/platform),
# with iceberg.rest-catalog.warehouse set to this tenant's own namespace so
# Nessie can enforce per-tenant catalog ACLs (see the tenancy-architecture
# reference page's "Cross-tenant data sharing" section).
#
# KNOWN GAP: this doesn't yet configure Trino's resource-groups.json for
# query-level CPU/memory quotas per tenant on a shared cluster -- the
# ResourceQuota in namespace.tf covers pod-level requests/limits, but true
# query-level resource groups (the pool tier's other isolation mechanism,
# per the tenancy-architecture page) are a real next step, not yet wired up.

locals {
  iceberg_catalog_properties = <<-PROPERTIES
    connector.name=iceberg
    iceberg.catalog.type=rest
    iceberg.rest-catalog.uri=${var.catalog_uri}
    iceberg.rest-catalog.warehouse=${var.tenant_id}
    fs.native-s3.enabled=true
    s3.aws-access-key=minioadmin
    s3.aws-secret-key=minioadmin
    s3.endpoint=http://minio.${var.tenant_id}.svc.cluster.local:9000
    s3.path-style-access=true
    s3.ssl.enabled=false
    iceberg.file-format=PARQUET
  PROPERTIES
}

resource "helm_release" "trino" {
  name       = "trino"
  repository = "https://trinodb.github.io/charts"
  chart      = "trino"
  namespace  = kubernetes_namespace_v1.tenant.metadata[0].name

  values = [
    file("${path.module}/../../../helm-values/trino-values.yaml"),
    yamlencode({
      additionalCatalogs = {
        iceberg = local.iceberg_catalog_properties
      }
    }),
  ]

  depends_on = [helm_release.minio]
}
