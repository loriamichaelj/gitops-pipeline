# bootstrap/seed

Creates what CI needs before it can do anything else:

- the OpenTofu **state bucket** (versioned, private, one prefix per stack),
- the **GitHub OIDC trust**: a workload identity pool and provider that accept
  tokens only from this repository (matched by numeric repository and owner ID),
- one **service account per GitHub environment**, each impersonable only by jobs
  running in that environment (the token subject must match GitHub's immutable
  format, `repo:<owner>@<id>/<name>@<id>:environment:<env>`):

| Environment | Can do | Gate |
|---|---|---|
| `ci` | read project and state; plan only | none |
| `seed` | manage this module (pool, service accounts, IAM, bucket) | approval, `dev` branch only |
| `dev` | read/write state under `dev/` only; no project roles yet | `dev` branch only |

The `seed` workflow (`.github/workflows/seed.yml`) plans in `ci` and applies in
`seed`.

## First run

The trust does not exist until this module creates it, so the first apply cannot
use OIDC. An operator runs it once with their own credentials and a local
backend, then moves the state into the bucket it just created.

```sh
cd bootstrap/seed
cp terraform.tfvars.example terraform.tfvars   # project_id, repository_id, repository_owner_id

# local backend for this run only (the override file is gitignored)
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
tofu init && tofu apply

# move state into the bucket, then drop the local copy
rm backend_override.tf
tofu init -migrate-state -force-copy -backend-config="bucket=$(tofu output -raw state_bucket)"
rm -f terraform.tfstate terraform.tfstate.backup

# give the GitHub environments their identifiers
../../scripts/seed-github-secrets.sh "$(gh repo view --json nameWithOwner -q .nameWithOwner)" "$(tofu output -raw state_bucket)"
```

If your Application Default Credentials bill a different quota project, set
`GOOGLE_USER_PROJECT_OVERRIDE=true GOOGLE_BILLING_PROJECT=<project_id>` for the run.

## Afterwards

Change this module through a pull request. Run the `seed` workflow from `dev`
with `apply` ticked and approve it in the `seed` environment.
