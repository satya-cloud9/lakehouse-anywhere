# The cluster itself, via the same `kind` CLI the rest of this repo already
# uses (see docs/architecture.md's "Why not simulate EKS itself" -- floci's
# own EKS emulation would just be another layer of indirection over the
# same kind cluster). Deliberately plain `null_resource` + the `kind` CLI
# rather than a Terraform kind provider, so this module has no unverified
# third-party Terraform provider in it -- only the AWS provider (against
# floci) and `null`, both already exercised elsewhere in this repo.

resource "null_resource" "kind_cluster" {
  triggers = {
    config_path  = var.kind_config_path
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if kind get clusters 2>/dev/null | grep -qx "${var.cluster_name}"; then
        echo "kind cluster '${var.cluster_name}' already exists, reusing it."
      else
        kind create cluster --name "${var.cluster_name}" --config "${var.kind_config_path}"
      fi
      mkdir -p "${path.module}/generated"
      kind get kubeconfig --name "${var.cluster_name}" > "${path.module}/generated/kubeconfig"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name '${self.triggers.cluster_name}' || true"
  }
}
