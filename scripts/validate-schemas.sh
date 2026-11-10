#!/usr/bin/env bash
# Schema checks over everything the hub syncs. Run scripts/render.sh and
# scripts/test-compositions.sh first.
#   kubeconform: Kubernetes, Argo CD and Crossplane core kinds.
#   crossplane resource validate: provider-managed kinds and platform XRs, against
#     the pinned provider packages and our XRDs (no public JSON schemas exist).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Pinned: kubernetes-json-schema has no 1.37 yet; core kinds used here are stable.
k8s_version=1.34.12
crd_catalog=https://raw.githubusercontent.com/datreeio/CRDs-catalog/49729e49e8f062933e3716a26540d41b0cd0856c
xp_version="v$(yq -r .crossplane.chartVersion platform/argocd/root/values.yaml)"

# Kinds without a public schema, checked by crossplane resource validate below.
crossplane_validated=XBucket,Bucket,XNetwork,Network,Subnetwork,ClusterProviderConfig
# CustomResourceDefinitions ship unmodified in upstream charts, and
# kubernetes-json-schema publishes no strict schema for them.

echo "== kubeconform"
kubeconform -strict -summary -output text \
  -kubernetes-version "$k8s_version" \
  -schema-location default \
  -schema-location "$crd_catalog/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
  -skip "$crossplane_validated,CustomResourceDefinition" \
  rendered/root.yaml rendered/argocd.yaml rendered/crossplane.yaml \
  rendered/crossplane-providers-gcp.yaml \
  platform/crossplane/functions platform/apis platform/policies infrastructure

echo "== crossplane resource validate"
ext=rendered/extensions
rm -rf "$ext"
mkdir -p "$ext"
yq 'select(.kind == "Provider")' rendered/crossplane-providers-gcp.yaml >"$ext/providers.yaml"
cp platform/crossplane/functions/functions.yaml "$ext/functions.yaml"
for xrd in platform/apis/*/definition.yaml; do
  cp "$xrd" "$ext/$(basename "$(dirname "$xrd")")-definition.yaml"
done

resources=rendered/crossplane-resources.yaml
{
  yq 'select(.kind != "ConfigMap")' rendered/crossplane-providers-gcp.yaml
  find platform/apis infrastructure rendered/compositions -name '*.yaml' ! -name 'definition.yaml' \
    -exec sh -c 'for f; do echo "---"; cat "$f"; done' _ {} +
} >"$resources"

crossplane resource validate "$ext" "$resources" \
  --crossplane-image "xpkg.crossplane.io/crossplane/crossplane:$xp_version" \
  --error-on-missing-schemas --skip-success-results
