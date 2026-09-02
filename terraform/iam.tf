# IAM roles for Trino and Kestra, written in the IRSA (IAM Roles for Service
# Accounts) shape you'd use on real EKS — a role trusted by the cluster's
# OIDC provider, assumed by a matching Kubernetes ServiceAccount. Under
# LocalStack there is no real OIDC provider or STS enforcement, so this
# mainly validates the policy documents and role/policy wiring; the actual
# local Trino/Kestra pods authenticate to MinIO with static credentials
# instead (see helm-values/*.yaml). Swapping to real IRSA is a real-AWS step.

data "aws_iam_policy_document" "lakehouse_data_access" {
  statement {
    sid    = "S3Warehouse"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.iceberg_warehouse.arn,
      "${aws_s3_bucket.iceberg_warehouse.arn}/*",
    ]
  }

  statement {
    sid    = "GlueCatalog"
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:GetTable",
      "glue:GetTables",
      "glue:DeleteTable",
      "glue:GetPartitions",
      "glue:BatchCreatePartition",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KmsForWarehouse"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.lakehouse.arn]
  }
}

resource "aws_iam_policy" "lakehouse_data_access" {
  name   = "${var.project_name}-data-access"
  policy = data.aws_iam_policy_document.lakehouse_data_access.json
}

# --- Trino role ---

data "aws_iam_policy_document" "trino_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"] # placeholder trust — replace with the real OIDC provider ARN/condition once pointed at real EKS
    }
  }
}

resource "aws_iam_role" "trino" {
  name               = "${var.project_name}-trino"
  assume_role_policy = data.aws_iam_policy_document.trino_trust.json
}

resource "aws_iam_role_policy_attachment" "trino_data_access" {
  role       = aws_iam_role.trino.name
  policy_arn = aws_iam_policy.lakehouse_data_access.arn
}

# --- Kestra role ---

resource "aws_iam_role" "kestra" {
  name               = "${var.project_name}-kestra"
  assume_role_policy = data.aws_iam_policy_document.trino_trust.json
}

resource "aws_iam_role_policy_attachment" "kestra_data_access" {
  role       = aws_iam_role.kestra.name
  policy_arn = aws_iam_policy.lakehouse_data_access.arn
}
