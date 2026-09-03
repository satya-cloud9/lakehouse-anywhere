# Glue Data Catalog: the Iceberg table metadata catalog Trino's Iceberg
# connector reads/writes against (catalog-type = glue in
# helm-values/trino-values.yaml). floci supports the core
# Glue Data Catalog APIs (CreateDatabase/CreateTable/GetTable/etc.) needed
# for this without a Pro license.

resource "aws_glue_catalog_database" "iceberg" {
  name        = "${var.project_name}_iceberg"
  description = "Iceberg table metadata for the lakehouse warehouse"

  create_table_default_permission {
    permissions = ["ALL"]

    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }
}
