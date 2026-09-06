# Real k3s install over SSH -- this is the one provider module in this repo
# that isn't a contract-test double, because there's no cloud API to
# emulate here: the machine already exists. Requires passwordless sudo for
# ssh_user (typical on a freshly-imaged box you control yourself; add a
# `-t` + password prompt to the remote-exec connection block below if
# yours needs one).

locals {
  version_env = var.k3s_version != "" ? "INSTALL_K3S_VERSION=${var.k3s_version} " : ""
}

resource "null_resource" "k3s_install" {
  triggers = {
    host        = var.host
    k3s_version = var.k3s_version
  }

  connection {
    type        = "ssh"
    host        = var.host
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | ${local.version_env}sh -s - --write-kubeconfig-mode 644",
      "sudo systemctl is-active --quiet k3s || (echo 'k3s failed to start -- check: sudo journalctl -u k3s' && exit 1)",
    ]
  }
}

# k3s writes its kubeconfig server address as https://127.0.0.1:6443, which
# only resolves correctly from on the box itself. Fetch it and rewrite the
# host so it's usable from wherever you run `tofu apply`/`kubectl` next
# (your workstation, or the CI box the rest of this repo runs from).
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.k3s_install]

  triggers = {
    host = var.host
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${path.module}/generated"
      ssh -i "${var.ssh_private_key_path}" -o StrictHostKeyChecking=accept-new \
        "${var.ssh_user}@${var.host}" "sudo cat /etc/rancher/k3s/k3s.yaml" \
        | sed "s/127.0.0.1/${var.host}/" \
        | sed "s/default/${var.cluster_name}/" \
        > "${path.module}/generated/kubeconfig"
    EOT
  }
}
