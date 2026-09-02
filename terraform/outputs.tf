output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "glue_database_name" {
  value = aws_glue_catalog_database.iceberg.name
}

output "iceberg_warehouse_bucket" {
  value = aws_s3_bucket.iceberg_warehouse.bucket
}

output "trino_iam_role_arn" {
  value = aws_iam_role.trino.arn
}

output "kestra_iam_role_arn" {
  value = aws_iam_role.kestra.arn
}

output "kms_key_id" {
  value = aws_kms_key.lakehouse.key_id
}
