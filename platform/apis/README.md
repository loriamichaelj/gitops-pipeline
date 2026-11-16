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

Each is rendered by its cloud's provider chart (`platform/crossplane/providers/gcp`, `.../aws`, `.../azure`) on a hub labelled for that cloud.

## Status

The Compositions for all three clouds are written and tested. Only GCP has an identity applied; AWS and Azure identities exist as code and are off by default:

| | GCP | AWS | Azure |
|---|---|---|---|
| Compositions | yes | yes | yes |
| Snapshot and error tests | yes | yes | yes |
| Checked against provider CRDs | yes | yes | yes |
| Provider chart and ApplicationSet | yes | yes | yes |
| Hub identity (bootstrap, off by default) | yes | yes | yes |

Each cloud is checked against the schemas of the providers its chart installs. No
hub is labelled `aws-identity=federated` or `azure-identity=federated`, so those
charts sync nowhere until `bootstrap/local` is applied with them enabled.

## Enabling a cloud on a hub

Nothing here deploys. A hub needs three things before it can create AWS or Azure
resources:

1. **Provider chart**: all three exist (`platform/crossplane/providers/<cloud>`, one
   provider per family, each authenticating with a projected token, no stored keys).
   GCP and AWS give each family its own service account or role. Azure keeps the
   client ID in the shared `ClusterProviderConfig`, so its three families share one
   managed identity, with one federated credential per family service account.
2. **Identity at bootstrap**: `bootstrap/modules/aws-identity` and `azure-identity`
   create the trust and one role per AWS family, or one managed identity for Azure,
   and `bootstrap/local` writes the facts the charts read as cluster Secret
   annotations: `aws.gitops-pipeline/account-id`, `/audience`,
   `/role.provider-aws-s3`, `/role.provider-aws-ec2`; and
   `azure.gitops-pipeline/tenant-id`, `/subscription-id`, `/client-id`, `/audience`.
   AWS and Azure fetch the issuer's discovery document and keys over public HTTPS,
   unlike GCP, which accepts an uploaded copy, so the hub's issuer must be published
   first (README, "Give the hub AWS or Azure identity").
3. **Label** the hub's cluster Secret `<cloud>-identity=federated`; bootstrap does this
   when the cloud is enabled. This switches on
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
   and its provider family to the cloud's chart under `platform/crossplane/providers/`
   (and its `values.yaml` `families`, if it is a new family).
4. Run `make validate`.
