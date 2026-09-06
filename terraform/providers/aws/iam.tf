# IAM roles for Trino and Kestra, written in the IRSA (IAM Roles for Service
# Accounts) shape you'd use on real EKS -- a role trusted by the cluster's
# OIDC provider, assumed by a matching Kubernetes ServiceAccount. Under
# floci there is no real OIDC provider or STS enforcement, so this mainly
# validates the policy documents and role/policy wiring; the actual local
# Trino/Kestra pods authenticate to MinIO with static credentials instead
# (see terraform/platform and terraform/tenants). Swapping to real IRSA is
# a real-AWS step.
#
# These role ARNs are extra outputs beyond the four in the provider
# contract (see terraform/providers/CONTRACT.md) -- every provider exposes
# whatever its own workload_identity_mechanism actually needs (an IAM role
# ARN here, a GCP service-account email in providers/gcp, an Azure managed
# identity client ID in providers/azure, a Secret name for bare metal).
# terraform/tenants picks the right one to wire up based on the
# workload_identity_mechanism string each provider hands back.

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
      aws_s3_bucket.parity.arn,
      "${aws_s3_bucket.parity.arn}/*",
    ]
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
      identifiers = ["eks.amazonaws.com"] # placeholder trust -- replace with the real OIDC provider ARN/condition once pointed at real EKS
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
