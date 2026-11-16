# infrastructure

Cloud resources the hub reconciles, one folder per environment and cloud:
`infrastructure/<env>/<cloud>/*.yaml`, each file an XR (`XBucket`, `XNetwork`) in
namespace `infra-<env>`.

Nothing is checked in here, so nothing is deployed. The earlier sample XRs
(a GCS bucket and a VPC in `dev`/`gcp`) were removed; deleting their folder made
Argo CD delete the Application, and its finalizer deletes the XRs and their cloud
resources. That takes effect once the change reaches `dev` and the hub is running.

## Runbook

Only GCP can deploy today (see `platform/apis/README.md`). Every step below goes
through a pull request to `dev`; never `kubectl apply` an XR by hand.

### Add a resource

1. Add `infrastructure/dev/gcp/<name>.yaml`, one XR per file in namespace `infra-dev`,
   with `spec.crossplane.compositionSelector.matchLabels.cloud: gcp`. Copy the example
   in the root README. Start with `deletionPolicy: Orphan`.
2. Check it before opening the PR. `make policies` and `make schemas` validate it. To
   see the cloud resources it will produce, render it with the hub's facts:

   ```sh
   crossplane composition render infrastructure/dev/gcp/<name>.yaml \
     platform/apis/<bucket|network>/composition-gcp.yaml \
     platform/crossplane/functions/functions.yaml \
     --required-resources=tests/compositions/xbucket-gcp-defaults/required-resources.yaml
   ```

3. Open the PR. CI runs validate, scan and the secret scan. After merge, Argo CD's
   `infra-dev-gcp` Application picks the folder up.

The first time a folder appears under a cloud with no Application yet, Argo CD
creates one; the cloud's `infrastructure-<cloud>` ApplicationSet needs the hub's
cluster Secret to carry `<cloud>-identity=federated`.

### Check that it worked

Reads only. Run them from a shell with the hub's kubeconfig
(`export KUBECONFIG=$(tofu -chdir=bootstrap/local output -raw kubeconfig)`) and your
own `gcloud` login.

```sh
kubectl -n argocd get application infra-dev-gcp          # Synced, Healthy
kubectl -n infra-dev get xbucket,xnetwork                # SYNCED and READY True
kubectl get managed                                      # every composed resource READY True
gcloud storage buckets list --filter='labels.repo=gitops-pipeline'
gcloud compute networks list --filter='name~^infra-dev-'
gcloud compute networks subnets list --filter='name~^infra-dev-'
```

If an XR is not `READY`, `kubectl -n infra-dev describe <kind> <name>` and
`kubectl describe` on the managed resource it names show Crossplane's error. A
permission error from GCP means the provider family's service account lacks a role:
fix it in `bootstrap/local/main.tf` (`gcp_workloads`).

### Change a resource

Edit the XR in a PR. After merge Argo CD applies it and Crossplane updates the
resource. Parameters that a cloud cannot change in place (a bucket's location, a
subnet's range) make the resource fail to reconcile; delete and recreate instead.

### Remove a resource

Delete the XR file, or the whole folder, in a PR.

- With `deletionPolicy: Delete` (the default) the cloud resource is deleted. A bucket
  with objects is deleted only when `forceDestroy: true`.
- With `deletionPolicy: Orphan` the XR goes and the cloud resource stays. Remove it
  yourself with `gcloud` if you no longer want it.
- Deleting the folder removes its Application, and the Application's finalizer deletes
  the XRs, so the same rules apply.

### Proving the loop (the MVP)

`dev` has no claims on purpose. The first two (an empty bucket and a free VPC with one
subnet, both `Orphan`) are on a local branch, `first-claims`. To take the loop live:
merge that branch through a PR, run the checks above, change a parameter in a second
PR, then delete the files in a third. Switch the claims to `Delete` first if you want
the last step to remove the cloud resources too.
