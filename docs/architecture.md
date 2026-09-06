# Architecture notes

## Why this runs the same on any cloud's Linux box

"Deploy this on any cloud" splits into two very different questions
depending on which layer you mean, and it's worth being precise about
which one this repo actually solves.

**Below the Kubernetes API — provisioning the VM and its tooling.** This
was already accidentally cloud-agnostic by construction, because nothing
here calls a real cloud's API: floci and kind stand in for AWS/EKS, so
the only things that vary across "which cloud is this box on" are the
OS's package manager and CPU architecture — not the cloud provider
itself. `scripts/01-install-deps.sh` used to assume Ubuntu/apt/amd64
directly, which was the one place that leaked a specific provider's
default image into what should've been provider-agnostic. It now
detects the package manager (apt/dnf/yum) and architecture (amd64/arm64)
at runtime, so the identical script runs unmodified whether the box is
an AWS EC2 Ubuntu instance, a DigitalOcean Ubuntu/Debian droplet, an
Oracle Cloud Ampere (ARM) instance, a Rocky/Alma/RHEL box, or bare metal.
Docker's, helm's, and OpenTofu's own install scripts already do their
own OS/arch detection internally — the fix only needed to touch the
`kind`/`kubectl` direct-binary-download URLs and the base-package
install commands, which were the two places hardcoded to
`apt-get`/`-amd64`.

**Above the Kubernetes API — Helm charts, K8s manifests, Kestra flows,
Terraform against floci.** This layer was already fully cloud-agnostic
too, but for a different reason: it never talks to a specific cloud at
all, only to the Kubernetes API (kind today, a real cluster later) and
to floci. This is also *why* it will need real work later, not none:
the day this points at a real managed Kubernetes service instead of
kind, "any cloud" stops being free. Real EKS vs. GKE vs. AKS each need
their own distinct Terraform resources to provision the cluster itself
(`aws_eks_cluster` vs. `google_container_cluster` vs.
`azurerm_kubernetes_cluster` — genuinely different APIs, not a config
difference), and that step doesn't unify across providers the way the
Helm/K8s-manifest layer above it does. The standard way production
setups handle this isn't one universal script — it's a small
provider-specific Terraform module for "provision compute + cluster"
per cloud, with everything above that line (Helm values, K8s manifests,
Kestra flows) staying identical regardless of which one provisioned it.
That's a deliberate later step (see "Why not simulate EKS itself"
below), not something this repo tries to solve today.

## Why LocalStack got swapped for floci

This repo originally ran LocalStack for the AWS control-plane emulation.
LocalStack's free community image was sunset on March 23, 2026 — pulling
`localstack/localstack:latest` now requires creating an account and an auth
token, and LocalStack archived the old open-source GitHub repos in the
process. floci is a newer MIT-licensed alternative that's wire-compatible
on the same port (4566) and the same `/_localstack/health` check, so the
swap didn't touch anything above the emulator layer — just
`docker-compose.floci.yml`, the container name, and the
`aws_emulator_endpoint` Terraform variable (previously `localstack_endpoint`).
It also has a much smaller footprint (~13 MiB idle, ~24ms startup vs
LocalStack's JVM-based ~250 MiB+/several seconds), which matters on our
16GB budget. The tradeoff: floci is a much younger, less battle-tested
project — worth watching for rough edges as we actually run this.

## Why MinIO *and* floci, not just one

floci has its own S3 implementation, so in principle it alone could serve
as both the AWS control plane and the S3 data plane. In practice, splitting
them — floci for control-plane APIs (IAM/STS/Glue/KMS/EC2), MinIO for the
actual object storage Trino reads and writes — is the pattern most local
Iceberg lakehouse setups converge on, because:

- MinIO is a purpose-built, fast S3-compatible object store; floci's S3
  emulation is fine for control-plane-adjacent operations (bucket
  creation, policy checks) but isn't the one built for the volume of small
  PUT/GET calls Iceberg's manifest-file-heavy layout generates.
- It mirrors how many real deployments already separate "the S3 API my
  IaC creates buckets against" from "the S3-compatible endpoint my data
  actually lives behind" when there's an on-prem or hybrid component.

## Why not simulate EKS itself

LocalStack could emulate the EKS *API* (Pro tier only), but under the hood
that emulation was just a `kind` cluster anyway — it didn't run a second,
more-real Kubernetes control plane for it. floci doesn't offer EKS
emulation as a distinct product tier at all — EKS is just one of its 85
in-process/Docker-backed services, but the same reasoning applies: pointing
Terraform's `kubernetes`/`helm` providers directly at a `kind` cluster gets
you the same practical result (a real Kubernetes API to apply manifests
against) without an extra layer of indirection to debug through when
something goes wrong.

The tradeoff: none of the EKS-specific control-plane behavior (the AWS
IAM ↔ Kubernetes RBAC mapping via `aws-auth`/access entries, EKS managed
node group lifecycle, the EKS add-ons system) gets exercised locally.
Moving to real EKS later means adding an actual `aws_eks_cluster` +
node group + IRSA-OIDC-provider Terraform layer that doesn't exist yet in
this repo — everything here assumes a Kubernetes API is already there to
target.

## Why Glue-via-floci for the Iceberg catalog, not a REST catalog

Trino's Iceberg connector supports several catalog backends (Glue, Hive
Metastore, a REST catalog like Nessie/Polaris, JDBC). Glue was picked
here specifically because it's the one that carries over to real AWS
with the least change — swap the floci endpoint override for nothing
(real Glue needs no endpoint override) and real IAM credentials, and the
same `additionalCatalogs.iceberg` block should work. A REST catalog
(Nessie/Polaris) gets you table branching/versioning semantics Glue
doesn't have, at the cost of another service to run and a bigger jump if
you eventually do move to real AWS Glue.

## Known gaps / things not yet exercised

- No ingress controller / TLS — everything is reached via
  `kubectl port-forward` (see `make status`). Fine for a single-operator
  test rig, not representative of how you'd expose these UIs on real EKS
  (ALB Ingress Controller + ACM, typically).
- No autoscaling (HPA/cluster autoscaler) — the whole point of a fixed-size
  `kind` cluster is a fixed, predictable footprint for this box.
- IAM policy correctness isn't actually validated — LocalStack Community
  accepts `terraform apply` for IAM resources without enforcing the policy
  document the way real AWS would. Treat the Terraform in this repo as
  "does the resource graph make sense," not "is this policy correct."
- Trino/Kestra metrics aren't wired into Prometheus yet (see the note at
  the bottom of `helm-values/kube-prometheus-stack-values.yaml`) — logs via
  Loki and dashboards via Grafana work out of the box; metrics need a
  ServiceMonitor added per component once the base stack is confirmed
  running.
