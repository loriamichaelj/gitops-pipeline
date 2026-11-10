#!/usr/bin/env bash
# Kyverno: test the policies themselves, then apply them to every folder of
# infrastructure/ as Argo CD would sync it.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "== kyverno test"
kyverno test tests/policies

echo "== kyverno apply: infrastructure/"
find infrastructure -name '*.yaml' -exec dirname {} \; | sort -u | while read -r dir; do
  echo "-- $dir"
  kyverno apply platform/policies --resource "$dir" -u tests/policies/argocd/userinfo.yaml
done
