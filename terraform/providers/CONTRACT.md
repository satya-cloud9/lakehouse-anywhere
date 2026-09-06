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
