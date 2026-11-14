# Platform APIs

Each API (`bucket`, `network`) has one XRD and one Composition per cloud. The XRD
is shared; the Composition is chosen per XR by its `compositionSelector`:

```yaml
spec:
  crossplane:
    compositionSelector:
      matchLabels:
        cloud: gcp   # or aws, azure
```

The Kyverno policy `xr-composition-selector` rejects an XR without one of these
three values, so a new Composition can never silently re-home existing resources.

## What each API creates

| API | GCP | AWS | Azure |
|---|---|---|---|
| `XBucket` | GCS bucket: uniform access, public access prevention enforced | S3 bucket, public access block (all four settings), versioning resource | Resource group, StorageV2 account (no public blobs), private container |
| `XNetwork` | Custom-mode VPC and one subnet, optional GKE secondary ranges | VPC and one private subnet covering the same range | Resource group, virtual network and one subnet covering the same range |

Every resource that takes labels or tags carries `managed-by=crossplane`,
`repo=gitops-pipeline`, `cloud`, `env`, `xr-namespace` and `xr-name`.

## Parameters by cloud

| Parameter | GCP | AWS | Azure |
|---|---|---|---|
| `XBucket.location` | GCS location, default `US-CENTRAL1` | S3 region, default `us-east-1` | Azure region, default `eastus` |
| `XBucket.storageClass` | all four classes | `STANDARD` only: S3 classes are per object | `STANDARD` → Hot, `NEARLINE`/`COLDLINE` → Cool; `ARCHIVE` is refused (per blob on Azure) |
| `XBucket.forceDestroy` | yes | yes | not enforced: deleting the XR deletes the container and its blobs even when `false`. Use `deletionPolicy: Orphan` to keep data |
| `XNetwork.region` | default `us-central1` | default `us-east-1`; the subnet goes in zone `<region>a` | default `eastus` |
| `XNetwork.podsCidr`, `servicesCidr` | GKE secondary ranges | refused | refused |

A storage class or range a cloud cannot honour fails the render with a message
naming the parameter, rather than being dropped. `forceDestroy` on Azure is the one
exception, noted above.

## Names and adoption

Cloud names are derived from the cloud account, the XR's namespace and name, so a
rebuilt hub finds the same resources:

- **GCP and AWS buckets**: `<namespace>-<name>-<hash>`, hashed with the project or
  account ID.
- **Azure**: the resource group, network and subnet share `<namespace>-<name>-<hash>`.
  The XR's kind is part of the hash, so an `XBucket` and an `XNetwork` with the same
  name never share a resource group (deleting a resource group deletes everything in
  it). Storage accounts are `st` plus 22 hex characters, because account names allow
  only 3 to 24 lowercase letters and digits.
- **AWS VPCs and subnets** get their identifiers from AWS, so they cannot be named in
  advance. The name above is their `Name` tag. A rebuilt hub creates new ones unless
  their IDs are set as `crossplane.io/external-name` by hand.

## Hub facts

Each Composition reads one `EnvironmentConfig` and fails with a clear message when
it is missing, which is what a hub without that cloud's identity sees:

| Cloud | EnvironmentConfig | Key |
|---|---|---|
| GCP | `gcp` | `projectID` |
| AWS | `aws` | `accountID` |
| Azure | `azure` | `subscriptionID` |

Only GCP's is rendered on a hub today (`platform/crossplane/providers/gcp`).

## Status

The Compositions for all three clouds are written and tested. Only GCP can deploy:

| | GCP | AWS | Azure |
|---|---|---|---|
| Compositions | yes | yes | yes |
| Snapshot and error tests | yes | yes | yes |
| Checked against provider CRDs | yes | yes | yes |
| Provider installed on the hub | yes | no | no |
| Hub identity and EnvironmentConfig | yes | no | no |

AWS and Azure are checked against the real provider schemas through
`platform/crossplane/schema-packages/`, which `scripts/validate-schemas.sh` loads.
Nothing installs those packages on a hub.

## Enabling a cloud on a hub

Nothing here deploys. To let a hub create AWS or Azure resources:

1. Install the cloud's providers on the hub with their identity wiring, as
   `platform/crossplane/providers/gcp` does for GCP (one provider per family, each
   with its own cloud identity, no stored keys), using the versions pinned in
   `platform/crossplane/schema-packages/`.
2. Render the cloud's `EnvironmentConfig` from the hub's cluster Secret.
3. Label the hub's cluster Secret `<cloud>-identity=federated`.
4. Add XRs under `infrastructure/<env>/<cloud>/` through a pull request to `dev`.

`platform/argocd/root/values.yaml` already lists `gcp`, `aws` and `azure`. Listing
a cloud creates nothing: an Application exists only for a folder that is checked in
and a hub labelled for that cloud.

## Adding an API or a cloud

1. Add `platform/apis/<api>/composition-<cloud>.yaml`. Its `metadata.labels.cloud` is
   `<cloud>` and its `spec.compositeTypeRef` names the XRD's kind.
2. Add a `<xrd>-<cloud>-defaults` case under `tests/compositions/`, plus a case for
   each error the Composition raises, then run `make update-snapshots` and review the
   diff.
3. Add any new managed kind to `crossplane_validated` in `scripts/validate-schemas.sh`
   and its provider package to `platform/crossplane/schema-packages/`.
4. Run `make validate`.
