#!/usr/bin/env bash
# Store the seed module's outputs as secrets on the GitHub environments the seed
# workflow uses. They are identifiers, not credentials; secrets are used so
# GitHub masks them in the public workflow logs.
# Needs: gh (admin on the repo), tofu, jq, and access to the state bucket.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

repo=${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
bucket=${2:?usage: seed-github-secrets.sh [owner/repo] <state-bucket>}

out=$(tofu -chdir=bootstrap/seed init -input=false -reconfigure -backend-config="bucket=$bucket" >/dev/null \
  && tofu -chdir=bootstrap/seed output -json)

project=$(jq -r .project_id.value <<<"$out")
provider=$(jq -r .workload_identity_provider.value <<<"$out")

for env in ci seed dev; do
  sa=$(jq -er ".service_accounts.value.$env" <<<"$out")
  gh secret set GCP_PROJECT_ID --env "$env" -R "$repo" --body "$project"
  gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --env "$env" -R "$repo" --body "$provider"
  gh secret set GCP_SERVICE_ACCOUNT --env "$env" -R "$repo" --body "$sa"
  gh secret set TF_STATE_BUCKET --env "$env" -R "$repo" --body "$bucket"
  echo "$env: $(gh secret list --env "$env" -R "$repo" --json name -q '[.[].name]|join(", ")')"
done
