#!/usr/bin/env bash
# Snapshot tests for Compositions. Each tests/compositions/<case>/ holds:
#   composition               path of the Composition under test
#   xr.yaml                   the XR to render
#   required-resources.yaml   optional: resources the pipeline requires
#   expected.yaml             expected render output, or
#   expected-error.txt        text the failing render must print
# UPDATE=1 rewrites expected.yaml from the current output.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

out=rendered/compositions
mkdir -p "$out"
xp_version="v$(yq -r .crossplane.chartVersion platform/argocd/root/values.yaml)"
functions=platform/crossplane/functions/functions.yaml
failed=0

for dir in tests/compositions/*/; do
  name=$(basename "$dir")
  args=("$dir/xr.yaml" "$(<"$dir/composition")" "$functions" "--crossplane-version=$xp_version")
  [[ -f $dir/required-resources.yaml ]] && args+=("--required-resources=$dir/required-resources.yaml")

  if [[ -f $dir/expected-error.txt ]]; then
    if crossplane composition render "${args[@]}" >"$out/$name.yaml" 2>"$out/$name.err"; then
      echo "FAIL $name: render succeeded, expected an error"; failed=1
    elif ! grep -qF -- "$(<"$dir/expected-error.txt")" "$out/$name.err"; then
      echo "FAIL $name: unexpected error:"; cat "$out/$name.err"; failed=1
    else
      echo "ok   $name (fails as expected)"
    fi
    rm -f "$out/$name.yaml"
    continue
  fi

  crossplane composition render "${args[@]}" >"$out/$name.yaml"
  if [[ ${UPDATE:-0} == 1 ]]; then
    cp "$out/$name.yaml" "$dir/expected.yaml"; echo "updated $name"
  elif diff -u "$dir/expected.yaml" "$out/$name.yaml"; then
    echo "ok   $name"
  else
    echo "FAIL $name: output differs from expected.yaml (UPDATE=1 to accept)"; failed=1
  fi
done

exit "$failed"
