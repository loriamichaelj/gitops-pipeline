#!/usr/bin/env bash
# OpenTofu bootstrap: formatting, validation of every root module, and trivy.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "== tofu fmt"
tofu fmt -check -recursive -diff bootstrap

for root in bootstrap/*/; do
  [[ $root == bootstrap/modules/ ]] && continue
  echo "== tofu validate: $root"
  tofu -chdir="$root" init -backend=false -input=false -lockfile=readonly >/dev/null
  tofu -chdir="$root" validate
done

echo "== trivy config"
trivy config --quiet --exit-code 1 --severity HIGH,CRITICAL bootstrap
