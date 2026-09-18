# See terraform/providers/CONTRACT.md -- the first four are the required
# contract; everything after is AWS-specific extra, consumed only by the
# IRSA wiring path in terraform/tenants when workload_identity_mechanism
# is "irsa".

output "kubeconfig_path" {
  description = "Local path to the kind cluster's kubeconfig."
  # abspath(): see the same note in providers/baremetal/outputs.tf -- this
  # value crosses into terraform/platform/tenants, which apply from a
  # different working directory, so a bare relative path breaks there.
  value      = abspath("${path.module}/generated/kubeconfig")
  depends_on = [null_resource.kind_cluster]
}

output "node_pool_refs" {
  description = "kind node names standing in for node-group identifiers."
  value       = ["${var.cluster_name}-control-plane", "${var.cluster_name}-worker", "${var.cluster_name}-worker2"]
}

output "workload_identity_mechanism" {
  value = "irsa"
}

output "storage_class_name" {
  description = "kind's built-in default StorageClass (local-path-provisioner). Real EKS would use gp3 via the EBS CSI driver instead."
  value       = "standard"
}

# --- AWS-specific extras ---

output "vpc_id" {
  value = aws_vpc.main.id
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

output "parity_bucket" {
  value = aws_s3_bucket.parity.bucket
}

# --- Object storage (CONTRACT.md's object-storage outputs) ---

output "object_storage_endpoint" {
  description = "See variables.tf's aws_emulator_pod_endpoint -- UNVERIFIED, confirm pod-reachability on first apply."
  value       = var.aws_emulator_pod_endpoint
}

output "object_storage_bucket" {
  value = aws_s3_bucket.parity.bucket
}

output "object_storage_access_key_id" {
  value     = aws_iam_access_key.object_storage.id
  sensitive = true
}

output "object_storage_secret_access_key" {
  value     = aws_iam_access_key.object_storage.secret
  sensitive = true
}
