# Testing platform and tenant

A consolidated, provider-agnostic verification pass for anything running
above the provider layer -- see `terraform/providers/CONTRACT.md`. Run this
after `scripts/04-apply-platform.sh` and `scripts/05-apply-tenant.sh` both
report success, on *any* provider (`baremetal`, `aws`, `gcp`, `azure`).
Nothing below should need to change based on which provider you're on --
if a step turns out to need a provider-specific tweak, that's the contract
leaking and worth fixing at the source, not silently patching this doc.

The one deliberate exception is the raw object-storage check (step 5):
AWS/GCP's contract-test doubles both expose an S3-compatible API, so the
same curl works for both; Azure Blob's native API is a genuinely different
shape, so that step's Azure version will need its own command once Azure
gets this far.

Every step here was worked out empirically against GCP's contract-test
double, including two real dead ends (wrong Nessie REST paths, a
misdiagnosed emulator race) -- the corrected version is what's below;
the wrong turns aren't repeated here, only the destination.

## 0. Prerequisites

```bash
export KUBECONFIG=$(cd terraform/providers/<provider> && tofu output -raw kubeconfig_path)
```

Replace `<provider>` with whichever one you just applied. Every other
command below assumes this is already exported.

## 1. Pod health sweep

Quick, provider-agnostic first pass before checking anything specific:

```bash
kubectl get pods -A | grep -v Running
```

Should return nothing, or only completed Jobs (e.g. a pool-tier tenant's
schema-creation Job shows `0/1 Completed`, which is correct, not a
failure). Anything else needs a look before continuing.

**Known false positive, not platform/tenant's fault**: on floci-gcp,
`prometheus-node-exporter` sits in `CreateContainerError` -- a DaemonSet
hostPath/privileged-mount issue specific to the nested k3s environment,
unrelated to anything in this doc. Confirm it's *that* pod specifically
before assuming a real problem.

## 2. Nessie's catalog actually reachable

Not just the pod Running -- the REST API itself, and specifically the
Iceberg REST catalog surface Trino depends on.

```bash
kubectl port-forward -n platform svc/nessie 19120:19120 &
PF_PID=$!
sleep 3
curl -s http://localhost:19120/iceberg/v1/main/config | python3 -m json.tool
kill $PF_PID
```

**Path gotcha, confirmed the hard way**: Nessie's Iceberg REST endpoints
are mounted *per branch/reference*, and the reference segment goes
*between* `v1` and the resource, not before `v1` and not omitted --
`/iceberg/v1/{ref}/...`, with `main` as the default branch. Neither
`/iceberg/v1/namespaces` (no ref) nor `/iceberg/main/v1/namespaces`
(wrong order) is real; both 404 silently with an empty body, which looks
identical to a connectivity problem if you don't check the status line.
`/iceberg/v1/main/config`'s own response includes an `endpoints` list and
a `defaults.prefix` field -- trust that over guessing from the general
Iceberg REST spec, since Nessie's branch model makes it deviate from the
spec's plain-vanilla path shape.

To list what's actually in the catalog:

```bash
kubectl port-forward -n platform svc/nessie 19120:19120 &
PF_PID=$!
sleep 3
curl -s http://localhost:19120/iceberg/v1/main/namespaces | python3 -m json.tool
curl -s http://localhost:19120/iceberg/v1/main/namespaces/default/tables | python3 -m json.tool
kill $PF_PID
```

## 3. A real flow, verified by querying the table directly

Never trust Kestra's own execution-status badge as proof -- query the
actual table:

```bash
kubectl get svc -n tenant-a   # confirm the real service/deployment names -- don't assume they match another provider's naming
kubectl exec -it -n tenant-a deploy/trino-coordinator -- trino --catalog iceberg --schema default --execute "SHOW TABLES;"
kubectl exec -it -n tenant-a deploy/trino-coordinator -- trino --catalog iceberg --schema default --execute "SELECT count(*) FROM <table>;"
```

A table appearing in `SHOW TABLES` proves the catalog commit succeeded --
it does **not** prove rows exist. Check the count, and if you need to go
deeper, pull the table's full metadata directly from Nessie:

```bash
kubectl port-forward -n platform svc/nessie 19120:19120 &
PF_PID=$!
sleep 3
curl -s http://localhost:19120/iceberg/v1/main/namespaces/default/tables/<table> | python3 -m json.tool
kill $PF_PID
```

The `snapshots[].summary` block tells you what actually happened on the
last write -- `total-records`, `total-data-files`, and `manifests-created`
being `"0"` means a snapshot committed successfully but wrote no data,
which is a materially weaker claim than "a real row landed," even though
`SHOW TABLES` and a clean count query would both look identical either
way at a glance.

If a query against an existing table fails with a filesystem-level error
(a `NullPointerException` in `S3InputFile.length()` was the real one hit
here), that's a sign the object-storage layer and the catalog have
drifted -- go to step 5 before assuming it's a Trino or Nessie bug.

## 4. Custom image pull actually happened over the network

```bash
kubectl get pod -n platform -l app.kubernetes.io/name=kestra -o jsonpath='{.items[0].status.containerStatuses[0].imageID}'
kubectl get events -n platform | grep -i pull
```

A real `ghcr.io/...@sha256:...` digest plus a fresh `Pulling`/`Pulled`
event pair (not just an already-cached image sitting on the node) is the
same standard AWS's pipeline proof used.

## 5. Object storage actually has what the catalog thinks it has

**AWS/GCP (S3-compatible emulation) -- generalize this to whichever
provider's `object_storage_endpoint` output you're using:**

```bash
tofu output -raw object_storage_endpoint    # run from terraform/providers/<provider>
curl -s "<that endpoint>/storage/v1/b/<bucket>/o" | python3 -m json.tool   # GCP's own JSON API shape
```

Cross-check a specific object's existence and size against a
`metadata-location` or `manifest-list` path pulled from step 3's Nessie
response -- URL-encode `/` as `%2F` in the object path. A `size`/
`content-length` mismatch or an outright 404 here, for an object the
catalog is confident exists, is the real signature of a storage/catalog
drift bug, not something query-side retrying will fix.

**Azure**: no equivalent command exists here yet -- Azure Blob's native
API is a different shape than S3's, so this step needs its own version
once Azure's provider module gets far enough to test against. Don't
reuse the S3 curl shape and assume it degrades gracefully; confirm it
explicitly when the time comes.

## 6. The tenant task-runner plugin's own disposable Pod

Proves per-tenant execution isolation, not just that Kestra itself runs:

```bash
kubectl get pods -n tenant-a --sort-by=.metadata.creationTimestamp | tail -5
kubectl logs -n tenant-a <that-pod-name>
```

Confirms the custom plugin created and ran a Pod *inside the tenant's own
namespace* (not platform's), running dbt against Trino and the catalog.

## What "all green" here actually proves, and doesn't

Passing every step above proves the same thing article two's pipeline
update proved for AWS: platform and tenant, unmodified, work against this
provider's contract outputs, and a real flow can write through Trino into
Iceberg against this provider's real object storage. It does not prove
this against real managed services (still a contract-test double
underneath), and it does not prove multi-provider operation -- both
caveats article two already holds itself to, and this doc inherits rather
than restates.

