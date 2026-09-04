# lakehouse-on-eks (local simulator)

A local build/test rig for a lakehouse stack — Terraform, Kestra, Iceberg, Trino,
and observability — designed to run entirely on one Linux box via floci +
`kind`, before any of it touches a real AWS account. The end state (Terraform
providers, Helm charts, Kestra flows) is written to be as close as practical to
what you'd point at real AWS/EKS later — floci and kind stand in for AWS
and EKS, everything above that layer (Trino, Kestra, Iceberg, observability)
is the same software you'd run in production.

## How the AWS layer is simulated

There is no single "EKS simulator" here — two separate free/open tools cover
two separate concerns, which is also how most real local-lakehouse dev setups
are built:

- **floci** emulates the AWS *control plane*: IAM roles/policies, STS
  (for IRSA-style role assumption), the Glue Data Catalog (Iceberg table
  metadata), KMS, and VPC/EC2 resources (so Terraform's plan/apply graph is
  real and testable). This was originally LocalStack — swapped to floci
  because LocalStack's free community image was sunset on March 23, 2026 and
  now requires an account + auth token to pull. floci is MIT-licensed, no
  auth token ever, wire-compatible on the same port and health-check path,
  and much lighter (~13 MiB idle vs LocalStack's ~250 MiB+). Neither one
  enforces IAM policy the way real AWS does — `terraform apply` succeeding
  here doesn't guarantee the same IAM policy is actually correct against
  real AWS.
- **MinIO** is the S3-compatible *data plane* — the actual bytes (Parquet
  files, Iceberg metadata/manifest files) that Trino reads and writes. floci
  has an S3 implementation too, but MinIO is faster and more realistic for
  actual data I/O, so that's the split used here.
- **`kind`** is the Kubernetes substrate. We do not simulate the EKS control-plane
  API itself (that's a LocalStack Pro feature and just wraps a kind cluster
  under the hood anyway) — Terraform's Kubernetes/Helm providers point straight
  at the kind cluster, exactly as they would point at a real EKS cluster later.
  Swapping this out for real EKS later should mostly mean changing where the
  `kubernetes`/`helm` Terraform providers point.

## Components

| Layer | Component | Notes |
|---|---|---|
| AWS control plane | floci | IAM, STS, Glue Data Catalog, KMS, VPC/EC2 |
| AWS data plane | MinIO | S3-compatible object store for the Iceberg warehouse |
| Kubernetes | kind | 1 control-plane + 2 worker nodes |
| Query engine | Trino | Iceberg connector, catalog backed by Glue (via LocalStack) + MinIO |
| Orchestration | Kestra | standalone server + Postgres backend |
| Table format | Apache Iceberg | tables written/read through Trino |
| Metrics | kube-prometheus-stack (Prometheus + Grafana) | |
| Logs | Loki + Promtail | |
| Traces | Tempo | |
| IaC | Terraform (or OpenTofu) | targets floci via endpoint overrides |

## Sizing

Everything running concurrently needs roughly **7-8 vCPU / 13-15 GB RAM** in
requests. This repo assumes a **16 GB RAM / 8 vCPU** box running **Ubuntu
22.04 LTS**. If you're on less, see "Trimming the footprint" below.

## How this is meant to be run

This was built in a sandbox that can't reach Docker Hub or Hashicorp's
servers, so none of it has been run end to end yet — it's a first pass meant
to be run and iterated on *with you*. Run it phase by phase (not `make up`
blind on the first pass), and paste back the output of any phase that fails
or looks wrong. Each phase is independent enough that we can fix one without
re-running everything before it.

```
make preflight       # phase 0: check the box meets the sizing assumptions
make install          # phase 1: install docker, kind, kubectl, helm, tofu, awslocal
make floci-up          # phase 2: start floci, wait for it to be healthy
make tf-apply          # phase 3: terraform apply against floci
make kind-up           # phase 4: create the kind cluster
make deploy             # phase 5: helm install minio, trino, kestra, observability
make flows               # phase 6: register the example Kestra flow
make status               # print all service URLs / port-forward commands
```

`make down` tears down the kind cluster and stops floci, leaving Terraform
state and everything in git untouched. `make tf-destroy` additionally tears
down the Terraform-managed floci resources.

## Trimming the footprint (8 GB boxes)

If you're testing on something smaller than 16 GB:
- Skip Loki + Tempo initially (comment them out of `scripts/05-deploy-stack.sh`) —
  `kubectl logs` covers most early debugging.
- Cap Trino's JVM heap at 1.5-2 GB in `helm-values/trino-values.yaml`
  (`config.query.maxMemoryPerNode` / the coordinator/worker JVM `-Xmx`).
- Kestra's documented floor is 4 GB / 2 vCPU standalone — don't go below that.

## Repo layout

```
scripts/           setup scripts, run in numeric order
terraform/          AWS resources (VPC, IAM, Glue, KMS, S3) against floci
kind/                kind cluster topology
helm-values/     Helm values for MinIO, Trino, Kestra, observability
k8s/                  plain manifests (namespaces, configmaps) not covered by Helm
kestra/flows/    example Kestra flow definitions
trino/catalog/  reference Iceberg catalog properties (also generated as a ConfigMap)
docs/               architecture notes
```

## Getting this onto your GitHub repo

This directory is already a git repo with one commit per phase — extracting
the tarball is all the "cloning" you need to do; there's nothing further to
pull. On the cloud box (or wherever you have GitHub auth set up), from
inside this extracted directory:

```
git branch -m master main
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

Create the GitHub repo first, as **completely empty** — do not let GitHub
auto-initialize it with a README/license/.gitignore. If it's not empty
(auto-initialized, or you already pushed something else to it), `git push`
will be rejected because the two histories don't share a common ancestor;
either delete and recreate the repo empty, or `git push -u origin main --force`
if you're sure overwriting it is what you want.
