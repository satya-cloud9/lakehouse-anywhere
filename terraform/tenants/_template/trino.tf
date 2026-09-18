# The Iceberg catalog config is generated here (not in helm-values/trino-values.yaml)
# because it needs this tenant's own warehouse name interpolated in --
# catalog.type=rest points at Nessie (terraform/platform), with
# iceberg.rest-catalog.warehouse set to this tenant's own name so Nessie
# can enforce per-tenant catalog ACLs (see the tenancy-architecture
# reference page's "Cross-tenant data sharing" section).
#
# Object storage (s3.endpoint / s3.aws-*-key) is a pass-through of the
# provider layer's shared bucket now, not this tenant's own MinIO --
# see CONTRACT.md's "object-storage outputs" section. Every tenant
# currently points at the SAME bucket and the SAME credential, isolated
# only by the warehouse prefix Nessie maps this tenant's name to; real
# per-tenant credential scoping is documented there as not yet wired up.
#
# KNOWN GAP: this doesn't yet configure Trino's resource-groups.json for
# query-level CPU/memory quotas per tenant on a shared cluster -- the
# ResourceQuota in namespace.tf covers pod-level requests/limits, but true
# query-level resource groups (the pool tier's other isolation mechanism,
# per the tenancy-architecture page) are a real next step, not yet wired up.

locals {
  # fs.native-s3.enabled / s3.ssl.enabled are both stale against current
  # Trino (confirmed against v483, what `image.tag: latest` resolves to
  # today): the property was renamed to fs.s3.enabled, and s3.ssl.enabled
  # was removed outright -- SSL/TLS is inferred from s3.endpoint's own
  # scheme, not a separate flag.
  iceberg_catalog_properties = <<-PROPERTIES
    connector.name=iceberg
    iceberg.catalog.type=rest
    iceberg.rest-catalog.uri=${var.catalog_uri}
    iceberg.rest-catalog.warehouse=${var.tenant_id}
    fs.s3.enabled=true
    s3.region=us-east-1
    s3.aws-access-key=${var.object_storage_access_key_id}
    s3.aws-secret-key=${var.object_storage_secret_access_key}
    s3.endpoint=${var.object_storage_endpoint}
    s3.path-style-access=true
    iceberg.file-format=PARQUET
  PROPERTIES
}

resource "helm_release" "trino" {
  name       = "trino"
  repository = "https://trinodb.github.io/charts"
  chart      = "trino"
  namespace  = kubernetes_namespace_v1.tenant.metadata[0].name

  # Separate from the pod-level startupProbe tuning in trino-values.yaml --
  # this is Helm's own wait-for-ready timeout on the whole release
  # (provider default 300s), which was expiring before the coordinator/
  # worker's now-longer probe window even elapsed. Matched to roughly the
  # same ceiling so neither one gives up before the other.
  timeout = 600

  values = [
    file("${path.module}/../../../helm-values/trino-values.yaml"),
    yamlencode({
      additionalCatalogs = {
        iceberg = local.iceberg_catalog_properties
      }
    }),
  ]
}
