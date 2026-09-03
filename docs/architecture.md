# Architecture notes

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
