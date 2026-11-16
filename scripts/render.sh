#!/usr/bin/env bash
# Render every Helm source the hub syncs into rendered/ (gitignored), using the
# chart versions pinned in the root chart's values.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

out=rendered
rm -rf "$out"
mkdir -p "$out"

root_values=platform/argocd/root/values.yaml
val() { yq -r "$1" "$root_values"; }

helm template root platform/argocd/root --namespace argocd >"$out/root.yaml"

# Placeholder facts. On a hub they come from its Argo CD cluster Secret.
helm template crossplane-providers-gcp platform/crossplane/providers/gcp \
  --namespace crossplane-system \
  --set projectID=example-project \
  --set wifProvider=projects/123456789012/locations/global/workloadIdentityPools/example/providers/example \
  --set families.storage.serviceAccount=xp-gcp-storage@example-project.iam.gserviceaccount.com \
  --set families.compute.serviceAccount=xp-gcp-compute@example-project.iam.gserviceaccount.com \
  >"$out/crossplane-providers-gcp.yaml"

# A family without an identity yet is skipped, so a hub can sync a new family before
# bootstrap provisions its service account.
partial=$(helm template crossplane-providers-gcp platform/crossplane/providers/gcp \
  --namespace crossplane-system \
  --set projectID=example-project \
  --set wifProvider=projects/123456789012/locations/global/workloadIdentityPools/example/providers/example \
  --set families.storage.serviceAccount=xp-gcp-storage@example-project.iam.gserviceaccount.com)
if grep -q provider-gcp-compute <<<"$partial"; then
  echo "render: a family without a service account must not be rendered" >&2
  exit 1
fi

helm template crossplane-providers-aws platform/crossplane/providers/aws \
  --namespace crossplane-system \
  --set accountID=111122223333 \
  --set families.s3.roleARN=arn:aws:iam::111122223333:role/xp-aws-s3-example \
  --set families.ec2.roleARN=arn:aws:iam::111122223333:role/xp-aws-ec2-example \
  >"$out/crossplane-providers-aws.yaml"

partial=$(helm template crossplane-providers-aws platform/crossplane/providers/aws \
  --namespace crossplane-system \
  --set accountID=111122223333 \
  --set families.s3.roleARN=arn:aws:iam::111122223333:role/xp-aws-s3-example)
if grep -q provider-aws-ec2 <<<"$partial"; then
  echo "render: a family without a role must not be rendered" >&2
  exit 1
fi

helm template crossplane-providers-azure platform/crossplane/providers/azure \
  --namespace crossplane-system \
  --set tenantID=00000000-0000-0000-0000-000000000001 \
  --set subscriptionID=00000000-0000-0000-0000-000000000000 \
  --set clientID=00000000-0000-0000-0000-000000000002 \
  >"$out/crossplane-providers-azure.yaml"

helm template argocd argo-cd \
  --repo "$(val .argocd.chartRepo)" --version "$(val .argocd.chartVersion)" \
  --namespace argocd -f platform/argocd/values.yaml >"$out/argocd.yaml"

helm template crossplane crossplane \
  --repo "$(val .crossplane.chartRepo)" --version "$(val .crossplane.chartVersion)" \
  --namespace "$(val .crossplane.namespace)" -f platform/crossplane/install/values.yaml \
  >"$out/crossplane.yaml"

echo "rendered: $(ls "$out" | tr '\n' ' ')"
