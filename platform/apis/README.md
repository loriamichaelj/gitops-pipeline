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

GCP's and AWS's are rendered by their provider charts (`platform/crossplane/providers/gcp`, `.../aws`) on a hub labelled for that cloud. Azure's is not rendered yet.

## Status

The Compositions for all three clouds are written and tested. Only GCP can deploy:

| | GCP | AWS | Azure |
|---|---|---|---|
| Compositions | yes | yes | yes |
| Snapshot and error tests | yes | yes | yes |
| Checked against provider CRDs | yes | yes | yes |
| Provider chart and ApplicationSet | yes | yes | no |
| Hub identity (bootstrap) | yes | no | no |

AWS is checked against the schemas of the providers its chart installs. Azure is
checked against `platform/crossplane/schema-packages/`, which
`scripts/validate-schemas.sh` loads; nothing installs those packages on a hub.
No hub is labelled `aws-identity=federated`, so the AWS chart syncs nowhere.

## Enabling a cloud on a hub

Nothing here deploys. A hub needs three things before it can create AWS or Azure
resources:

1. **Provider chart**: AWS has one (`platform/crossplane/providers/aws`, one provider
   per family, each assuming its own IAM role through a projected token, no stored
   keys). Azure needs one written the same way, with the versions pinned in
   `platform/crossplane/schema-packages/`.
2. **Identity at bootstrap**: the cloud must trust the hub's service-account issuer
   and hold one role (or identity) per family. The chart reads its facts from the
   hub's cluster Secret annotations (`aws.gitops-pipeline/account-id`, `/audience`,
   `/role.provider-aws-s3`, `/role.provider-aws-ec2`). AWS and Azure fetch the
   issuer's discovery document and keys over public HTTPS, unlike GCP, which accepts
   an uploaded copy, so a kind hub needs its issuer published somewhere public first.
3. **Label** the hub's cluster Secret `<cloud>-identity=federated`. This switches on
   both the provider chart and the cloud's `infrastructure/<env>/<cloud>` folders.

Then add XRs under `infrastructure/<env>/<cloud>/` through a pull request to `dev`.

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
