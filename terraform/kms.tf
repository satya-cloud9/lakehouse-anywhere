resource "aws_kms_key" "lakehouse" {
  description             = "Encrypts the Iceberg warehouse bucket and Kestra secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-kms"
  }
}

resource "aws_kms_alias" "lakehouse" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.lakehouse.key_id
}
