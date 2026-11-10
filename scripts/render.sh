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
  >"$out/crossplane-providers-gcp.yaml"

helm template argocd argo-cd \
  --repo "$(val .argocd.chartRepo)" --version "$(val .argocd.chartVersion)" \
  --namespace argocd -f platform/argocd/values.yaml >"$out/argocd.yaml"

helm template crossplane crossplane \
  --repo "$(val .crossplane.chartRepo)" --version "$(val .crossplane.chartVersion)" \
  --namespace "$(val .crossplane.namespace)" -f platform/crossplane/install/values.yaml \
  >"$out/crossplane.yaml"

echo "rendered: $(ls "$out" | tr '\n' ' ')"
