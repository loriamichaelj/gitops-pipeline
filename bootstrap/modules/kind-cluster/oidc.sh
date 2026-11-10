#!/usr/bin/env bash
# Emit the cluster's service-account issuer and JWKS for an OpenTofu external data source.
# Input (stdin JSON): kubeconfig, context. Output (stdout JSON): issuer, jwks (JSON string).
set -euo pipefail

input=$(cat)
kubeconfig=$(jq -r '.kubeconfig' <<<"$input")
context=$(jq -r '.context' <<<"$input")

kc() { kubectl --kubeconfig "$kubeconfig" --context "$context" "$@"; }

issuer=$(kc get --raw /.well-known/openid-configuration | jq -r '.issuer')
jwks=$(kc get --raw /openid/v1/jwks | jq -c '.')

jq -n --arg issuer "$issuer" --arg jwks "$jwks" '{issuer: $issuer, jwks: $jwks}'
