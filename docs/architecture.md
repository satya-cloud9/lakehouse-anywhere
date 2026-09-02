# Architecture notes

## Why MinIO *and* LocalStack, not just one

LocalStack has its own S3 implementation, so in principle it alone could
serve as both the AWS control plane and the S3 data plane. In practice,
splitting them — LocalStack for control-plane APIs (IAM/STS/Glue/KMS/EC2),
MinIO for the actual object storage Trino reads and writes — is the
pattern most local Iceberg lakehouse setups converge on, because:

- MinIO is a purpose-built, fast S3-compatible object store; LocalStack's S3
  emulation is fine for control-plane-adjacent operations (bucket
  creation, policy checks) but isn't optimized for the volume of small
  PUT/GET calls Iceberg's manifest-file-heavy layout generates.
- It mirrors how many real deployments already separate "the S3 API my
  IaC creates buckets against" from "the S3-compatible endpoint my data
  actually lives behind" when there's an on-prem or hybrid component.

## Why not simulate EKS itself

LocalStack can emulate the EKS *API* (Pro tier only), but under the hood
that emulation is just a `kind` cluster anyway — LocalStack doesn't run a
second, more-real Kubernetes control plane for it. Given that, pointing
Terraform's `kubernetes`/`helm` providers directly at a `kind` cluster
gets you the same practical result (a real Kubernetes API to apply
manifests against) without a Pro license and without an extra layer of
indirection to debug through when something goes wrong.

The tradeoff: none of the EKS-specific control-plane behavior (the AWS
IAM ↔ Kubernetes RBAC mapping via `aws-auth`/access entries, EKS managed
node group lifecycle, the EKS add-ons system) gets exercised locally.
Moving to real EKS later means adding an actual `aws_eks_cluster` +
node group + IRSA-OIDC-provider Terraform layer that doesn't exist yet in
this repo — everything here assumes a Kubernetes API is already there to
target.

## Why Glue-via-LocalStack for the Iceberg catalog, not a REST catalog

Trino's Iceberg connector supports several catalog backends (Glue, Hive
Metastore, a REST catalog like Nessie/Polaris, JDBC). Glue was picked
here specifically because it's the one that carries over to real AWS
with the least change — swap the LocalStack endpoint override for nothing
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
