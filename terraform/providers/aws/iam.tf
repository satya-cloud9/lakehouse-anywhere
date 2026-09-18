# IAM roles for Trino and Kestra, written in the IRSA (IAM Roles for Service
# Accounts) shape you'd use on real EKS -- a role trusted by the cluster's
# OIDC provider, assumed by a matching Kubernetes ServiceAccount. Under
# floci there is no real OIDC provider or STS enforcement, so this mainly
# validates the policy documents and role/policy wiring; the actual local
# Trino/Kestra pods authenticate to MinIO with static credentials instead
# (see terraform/platform and terraform/tenants). Swapping to real IRSA is
# a real-AWS step.
#
# These role ARNs are extra outputs beyond the contract outputs (see
# terraform/providers/CONTRACT.md) -- every provider exposes whatever its
# own workload_identity_mechanism actually needs (an IAM role ARN here, a
# GCP service-account email in providers/gcp, an Azure managed identity
# client ID in providers/azure, a Secret name for bare metal).
# terraform/tenants picks the right one to wire up based on the
# workload_identity_mechanism string each provider hands back -- though
# today none of them are actually wired to anything yet (see this file's
# own header comment); the interim static credential every provider uses
# instead is CONTRACT.md's object_storage_access_key_id/secret_access_key.

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

# --- Object storage static credential (CONTRACT.md's object-storage outputs) ---
#
# IRSA (the roles above) is how a real EKS deployment would authenticate
# Trino/Kestra to S3 -- but that federation isn't wired to anything yet
# (this whole file exists to prove the policy documents are well-formed,
# not that a pod can actually assume them; see this file's own header
# comment). Until it is, object storage access uses the same kind of
# static credential bare metal's static-secret mechanism already uses,
# just as an IAM user/access-key pair here instead of a Kubernetes
# Secret's literal value. Every tenant shares this one credential today --
# scoping it per tenant is the real follow-up work CONTRACT.md flags.

resource "aws_iam_user" "object_storage" {
  name = "${var.project_name}-object-storage"
}

resource "aws_iam_user_policy_attachment" "object_storage_data_access" {
  user       = aws_iam_user.object_storage.name
  policy_arn = aws_iam_policy.lakehouse_data_access.arn
}

resource "aws_iam_access_key" "object_storage" {
  user = aws_iam_user.object_storage.name
}
