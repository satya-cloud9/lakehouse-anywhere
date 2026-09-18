# The provider contract

Every module under `terraform/providers/<name>/` does exactly one job:
turn "a region on this provider" into a working Kubernetes cluster, and
hand back four outputs in this exact shape. Nothing in `terraform/platform/`
or `terraform/tenants/` is allowed to read anything else from a provider
module, or to branch on which provider produced these values — that's
what keeps this repo reorganizable for a new provider without touching
the code above this line.

```hcl
output "kubeconfig_path" {
  description = "Local path to a kubeconfig file for the cluster this module created. Platform/tenant modules point their kubernetes/helm providers at this."
  value       = "..."
}

output "node_pool_refs" {
  description = "List of node-pool/node-group identifiers this module created (strings — provider-specific format is fine, this is opaque to everything above)."
  value       = ["..."]
}

output "workload_identity_mechanism" {
  description = "One of: irsa | workload-identity | azuread-workload-identity | static-secret. Tells the platform/tenant layer which pattern to use when wiring a pod's cloud credentials -- static-secret is the fallback for bare-metal/other, where there's no federation to use."
  value       = "..."
}

output "storage_class_name" {
  description = "Name of the Kubernetes StorageClass this module's cluster provisions PersistentVolumes against by default."
  value       = "..."
}
```

## Why these four and not more

`kubeconfig_path` is the only thing that actually has to be true for
anything above this line to work at all. The other three exist because
we already found real places the platform/tenant layer needs to make a
provider-shaped decision (which identity pattern to wire a ServiceAccount
to, which storage class to request in a PVC) — and the fix is to make
that decision data the provider module hands over, not a per-provider
`if` inside `terraform/platform` or `terraform/tenants`. If a future
change needs a fifth thing from every provider, it goes here first,
before any provider module is touched.

## The object-storage outputs

Added after finding that `terraform/platform`'s Nessie could not boot
without a specific tenant's MinIO already existing — a real dependency
running the wrong direction (platform depending on tenant, not the other
way around). The fix: object storage is a provider-layer concern, the
same way compute and identity already are. Every provider module now
also hands back:

```hcl
output "object_storage_endpoint" {
  description = "S3-API-compatible endpoint. Platform and tenant layers point Nessie/Trino's S3 client at this and never create or own a storage server themselves."
  value       = "..."
}

output "object_storage_bucket" {
  description = "Name of the single shared bucket/container for this environment. Tenant isolation is by path prefix inside it (s3://bucket/tenant-a/, tenant-b/, ...), not by separate buckets or servers."
  value       = "..."
}

output "object_storage_access_key_id" {
  description = "Static credential, sensitive. Real per-tenant access scoping via workload_identity_mechanism is a separate, not-yet-wired piece of work -- see docs/lakehouse-series article 3. Until that lands, every tenant shares this one credential and prefix-level isolation is a convention, not an enforced boundary."
  value       = "..."
  sensitive   = true
}

output "object_storage_secret_access_key" {
  value     = "..."
  sensitive = true
}
```

For bare metal there's no cloud storage API to call, so the provider
module runs a single shared MinIO instance itself -- as a plain Docker
container on the host, over the same SSH connection this module already
uses to install k3s (see storage.tf), not as a Kubernetes workload. That
keeps this module's original "only touches the box itself, never the
cluster's own API" rule intact, and it's a closer match to how real
cloud object storage actually works anyway: an external service pods
reach over the network, not something running inside the same cluster
it's meant to be independent of. For AWS/GCP/Azure this is the real
bucket the provider module already created as a contract-test-double
"parity" resource -- promoted here from validated-but-unused to actually
load-bearing.

**Known limitation, not yet solved by this change**: Nessie's own
warehouse-to-tenant mapping is still static server config, not something
that can be registered at runtime without a restart (confirmed against
Nessie's own docs -- there is no live API for this today). So while
platform no longer *depends on a tenant existing to boot*, platform's
code still has to know a tenant's name to give it a queryable warehouse
entry, and a real new-tenant onboarding still means a one-line addition
to `terraform/platform/catalog.tf` plus a re-apply. That's a smaller,
config-time coupling, not the boot-time one this change removes -- worth
being precise about the difference rather than claiming this fully
decouples platform from tenant identity.

## What's deliberately NOT in the contract

Anything AWS/GCP/Azure/bare-metal-specific that only the provider module
itself needs — VPC CIDRs, IAM policy documents, the exact cluster
resource type (`aws_eks_cluster` vs `google_container_cluster` vs
`azurerm_kubernetes_cluster` vs a `null_resource` running a k3s install
script) — stays inside that provider's own directory and is never an
input to anything else.

## Current implementations

| Provider | Real or contract-test double? | Backend |
|---|---|---|
| `baremetal/` | Real | k3s installed over SSH onto the actual box |
| `aws/` | Contract-test double | [floci](https://floci.io) (AWS control-plane emulator) + `kind` for the cluster itself — see `docs/architecture.md` for why this repo doesn't ask floci to emulate EKS directly |
| `gcp/` | Contract-test double | [floci-gcp](https://floci.io/gcp/) — its GKE emulation is documented as backed by a real local k3s cluster, so this module reads the kubeconfig floci-gcp hands back rather than standing up a separate `kind`/`k3s` cluster itself |
| `azure/` | Contract-test double | [floci-az](https://floci.io/az/) — same pattern as `gcp/`, verify the exact kubeconfig-retrieval mechanism empirically when you first `tofu apply` this, since floci-az's docs describe AKS coverage without spelling out that mechanism |

"Contract-test double" means: these prove the Terraform HCL is valid
against that cloud's real API shape, and prove the four-output contract
holds identically across three different providers, all for free and
before you own a single real cloud account. They do not prove real
EKS/GKE/AKS runtime behavior (their actual storage-class CSI driver,
their real load-balancer controller, IRSA/Workload Identity completing a
token exchange against real STS/Entra) — budget one real pass per cloud
against the genuine managed service before calling any of this
production-trusted.
