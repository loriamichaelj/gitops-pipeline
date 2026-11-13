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

## Adding a cloud

1. Add `platform/apis/<api>/composition-<cloud>.yaml` for every API the cloud
   supports. Its `metadata.labels.cloud` is `<cloud>`, and its
   `spec.compositeTypeRef` names the XRD's kind.
2. Put the cloud's provider and its identity wiring under `platform/crossplane/`
   (the GCP provider chart is the model), and add the hub-side identity Secret
   label `<cloud>-identity=federated` only once that identity exists.
3. Add a snapshot case under `tests/compositions/` for each new Composition, then
   run `make update-snapshots` and review the diff.

`platform/argocd/root/values.yaml` already lists `gcp`, `aws` and `azure` under
`infrastructure.clouds`. Listing a cloud creates no resources: an Application
exists only for a folder that is checked in and a hub labelled for that cloud.

## Status

| API | GCP | AWS | Azure |
|---|---|---|---|
| `XBucket` | Composition (GCS bucket) | not written | not written |
| `XNetwork` | Composition (custom VPC, one subnet) | not written | not written |

An XR for a cloud without a Composition has nothing to run in Crossplane, so it
never becomes ready.
