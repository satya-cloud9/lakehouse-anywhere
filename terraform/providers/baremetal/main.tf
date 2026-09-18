# Real k3s install over SSH -- this is the one provider module in this repo
# that isn't a contract-test double, because there's no cloud API to
# emulate here: the machine already exists.
#
# Requires genuine passwordless (NOPASSWD) sudo for ssh_user, with no
# workaround if it's missing -- there's no TTY on a `remote-exec`
# provisioner and nothing feeding it a password, so if k3s's installer's
# internal `sudo` re-exec ever needs one, this doesn't fail loudly, it just
# hangs indefinitely with zero output (indistinguishable from "still
# running" until you go check). Verify before relying on it:
#   ssh -i <ssh_private_key_path> <ssh_user>@<host> 'sudo -n true; echo exit:$?'
# exit:0 means you're fine. Anything else means grant it first, e.g.:
#   echo "<ssh_user> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-tofu-baremetal
#   sudo chmod 440 /etc/sudoers.d/90-tofu-baremetal
# (stock Ubuntu AMIs ship this for their default user via
# /etc/sudoers.d/90-cloud-init-users already -- if it's missing, something
# about the image or setup removed it.)

locals {
  version_env = var.k3s_version != "" ? "INSTALL_K3S_VERSION=${var.k3s_version} " : ""

  # pathexpand() so the default "~/.ssh/id_ed25519" (and any ~-based value
  # you pass) actually resolves -- file() below does NOT expand "~" on its
  # own, and neither does a quoted "~..." string in the local-exec shell
  # command further down, so both uses go through this instead of the raw
  # variable.
  ssh_private_key_path = pathexpand(var.ssh_private_key_path)

  # See variables.tf's object_storage_advertise_host doc comment -- this
  # is what actually goes into object_storage_endpoint (outputs.tf), kept
  # separate from var.host itself so fixing it doesn't force-replace
  # k3s_install/fetch_kubeconfig/object_storage (all of which key off
  # var.host in their own triggers, and are otherwise unaffected by this).
  object_storage_advertise_host = var.object_storage_advertise_host != "" ? var.object_storage_advertise_host : var.host
}

resource "null_resource" "k3s_install" {
  # host/ssh_user/ssh_key_path are duplicated into triggers (not just read
  # from var./local. in the connection block below) because a destroy-time
  # provisioner's connection block may ONLY reference self/count.index/
  # each.key -- confirmed the hard way via storage.tf's object_storage
  # resource hitting "Invalid reference from destroy provisioner" on the
  # exact same var.host/var.ssh_user/local.ssh_private_key_path pattern
  # this resource also used. This one just hadn't been exercised by a real
  # `tofu destroy` yet to surface it. self.triggers.* is the fix.
  triggers = {
    host         = var.host
    k3s_version  = var.k3s_version
    ssh_user     = var.ssh_user
    ssh_key_path = local.ssh_private_key_path
  }

  connection {
    type        = "ssh"
    host        = self.triggers.host
    user        = self.triggers.ssh_user
    private_key = file(self.triggers.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | ${local.version_env}sh -s - --write-kubeconfig-mode 644",
      "sudo systemctl is-active --quiet k3s || (echo 'k3s failed to start -- check: sudo journalctl -u k3s' && exit 1)",
    ]
  }

  # `tofu destroy` only removes Terraform's own state by default -- without
  # this, k3s stays installed and running on the target box afterward. k3s's
  # own installer drops an uninstall script for exactly this.
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "sudo /usr/local/bin/k3s-uninstall.sh || echo 'k3s-uninstall.sh not found or failed -- k3s may still be installed on this host.'",
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
    # interpreter: local-exec defaults to /bin/sh, which on Debian/Ubuntu is
    # dash -- dash doesn't understand `set -o pipefail` (bash-only) and
    # errors immediately with "Illegal option -o pipefail". Force bash
    # explicitly rather than dropping pipefail, since we actually want a
    # failed `ssh` mid-pipeline to fail the whole thing (otherwise a broken
    # ssh command here would still exit 0, because only the final `sed` in
    # the pipe determines the exit code without pipefail).
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${path.module}/generated"
      ssh -i "${local.ssh_private_key_path}" -o StrictHostKeyChecking=accept-new \
        "${var.ssh_user}@${var.host}" "sudo cat /etc/rancher/k3s/k3s.yaml" \
        | sed "s/127.0.0.1/${var.host}/" \
        | sed "s/default/${var.cluster_name}/" \
        > "${path.module}/generated/kubeconfig"
    EOT
  }
}
