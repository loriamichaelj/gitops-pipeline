#!/usr/bin/env bash
# Static security scans over the whole repository.
#   scan.sh trivy     misconfigurations (OpenTofu, Kubernetes, Helm), HIGH and CRITICAL
#   scan.sh checkov   policy checks (OpenTofu, GitHub Actions, Kubernetes), see .checkov.yaml
# With no argument both run.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Pinned by digest; the tag is only for readers.
checkov_image=bridgecrew/checkov:3.4.3@sha256:bfe9d70bb7f044aba49bd99675813445f106dee6072da583f51008cb667f3a63

run_trivy() {
  echo "== trivy config"
  trivy config --quiet --exit-code 1 --severity HIGH,CRITICAL \
    --skip-dirs rendered --skip-dirs tests --skip-dirs '**/.terraform' .
}

run_checkov() {
  echo "== checkov"
  docker run --rm -v "$PWD:/src:ro" -w /src -e HOME=/tmp "$checkov_image" \
    --config-file .checkov.yaml --directory .
}

case ${1:-all} in
  trivy) run_trivy ;;
  checkov) run_checkov ;;
  all) run_trivy; run_checkov ;;
  *) echo "usage: scan.sh [trivy|checkov]" >&2; exit 2 ;;
esac
