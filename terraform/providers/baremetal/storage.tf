# Shared object storage for this environment -- see CONTRACT.md's
# "object-storage outputs" section for why this exists at all (Nessie
# needed a storage backend that doesn't depend on any tenant existing).
#
# Runs as a plain Docker container on the host, over the same SSH
# connection main.tf already uses to install k3s -- deliberately NOT a
# Kubernetes workload. That keeps this module's "only touches the box
# itself, never the cluster's own API" rule intact (see versions.tf), and
# it's a closer match to how real cloud object storage actually works:
# S3/GCS/Blob are external services a cluster's pods reach over the
# network, not something running inside the cluster they serve. Pods
# reach this at http://<var.host>:<var.object_storage_port> the same way.
#
# One shared bucket, tenants isolated by path prefix inside it
# (s3://<bucket>/tenant-a/, tenant-b/, ...) -- by convention today, not
# yet enforced by policy. See CONTRACT.md's object_storage_access_key_id
# output description for that gap.
#
# Image is quay.io/minio/minio, not minio/minio -- confirmed against
# MinIO's own current docker docs (github.com/minio/minio/docs/docker/
# README.md): Docker Hub no longer hosts the official minio/minio image
# at all ("pull access denied ... repository does not exist"), and
# MinIO's own examples now use quay.io exclusively. Not a typo or a
# transient registry issue -- confirm this is still current if it breaks
# again later, since this is exactly the kind of upstream change this
# repo has no way to pin against.
#
# The bucket itself is created with `mc mb`, not by pre-creating a host
# directory and assuming MinIO will notice it. That was this file's
# original design and it does not hold up: confirmed live against this
# exact deployment (Nessie's ObjectStoresHealthCheck failed with
# NoSuchBucketException even though `mkdir -p .../warehouse` ran, and
# completed, before the container's first start -- the directory never
# even showed up inside the container's own /data afterward), and
# independently confirmed against how current MinIO deployment guides
# solve this same problem: every current "create a bucket when the
# container starts" recipe (e.g. Docker Compose examples) uses a
# dedicated `mc mb` step, none rely on directory presence. `mkdir -p`
# below now exists only to make sure the bind-mount source directory
# itself is there before Docker touches it -- it is not, on its own,
# what makes `object_storage_bucket` a bucket.

resource "null_resource" "object_storage" {
  # host/ssh_user/ssh_key_path are duplicated here (not just read from
  # var./local. in the connection block below) because a destroy-time
  # provisioner's connection block may ONLY reference self/count.index/
  # each.key -- referencing var.* or local.* there fails with "Invalid
  # reference from destroy provisioner" (confirmed against a real `tofu
  # apply`/`destroy` on this exact resource). self.triggers.* is the fix,
  # and it works identically for the create-time provisioner too, since
  # self.triggers holds the same values var./local. would have.
  triggers = {
    host           = var.host
    ssh_user       = var.ssh_user
    ssh_key_path   = local.ssh_private_key_path
    container_name = var.object_storage_container_name
  }

  connection {
    type        = "ssh"
    host        = self.triggers.host
    user        = self.triggers.ssh_user
    private_key = file(self.triggers.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Just the bind-mount source -- see the file header on why this
      # alone doesn't make object_storage_bucket a bucket.
      "mkdir -p ${var.object_storage_data_dir}",
      <<-EOT
        if sudo docker ps -a --format '{{.Names}}' | grep -qx ${var.object_storage_container_name}; then
          echo "${var.object_storage_container_name} already exists, reusing it."
        else
          sudo docker run -d \
            --name ${var.object_storage_container_name} \
            --restart unless-stopped \
            -p ${var.object_storage_port}:9000 \
            -p ${var.object_storage_console_port}:9001 \
            -e MINIO_ROOT_USER=${var.object_storage_root_user} \
            -e MINIO_ROOT_PASSWORD=${var.object_storage_root_password} \
            -v ${var.object_storage_data_dir}:/data \
            quay.io/minio/minio server /data --console-address :9001
        fi
      EOT
      ,
      <<-EOT
        # Wait for MinIO's own health endpoint before touching it with mc
        # -- the container above may have just started for the first
        # time, or (on reuse, e.g. after a host reboot) may still be
        # coming back up, and either way isn't guaranteed to be serving
        # requests the instant `docker run`/`docker ps` returns.
        for i in $(seq 1 30); do
          curl -sf http://localhost:${var.object_storage_port}/minio/health/live >/dev/null && break
          sleep 1
        done
        # `--ignore-existing` makes this safe to run every time this
        # resource is created, whether or not the bucket is already
        # there from a previous run.
        # --entrypoint sh: quay.io/minio/mc's default entrypoint is the mc
        # binary itself, so without this override "sh -c ..." gets parsed
        # as arguments to mc (mc treats "sh" as an unrecognized
        # subcommand) instead of actually running a shell. Confirmed live
        # on this exact image.
        sudo docker run --rm --network host --entrypoint sh quay.io/minio/mc \
          -c "mc alias set local http://localhost:${var.object_storage_port} ${var.object_storage_root_user} ${var.object_storage_root_password} && mc mb --ignore-existing local/${var.object_storage_bucket}"
      EOT
    ]
  }

  # Mirrors main.tf's own destroy-time provisioner for k3s -- `tofu
  # destroy` should actually remove what this resource created, not just
  # forget about it in Terraform's state.
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "sudo docker rm -f ${self.triggers.container_name} || echo 'container not found or already removed.'",
    ]
  }
}
