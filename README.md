# gitops-pipeline

A GitOps pipeline project for multi-cloud infrastructure and delivery.

## Secret scanning

Secrets are checked in three places, all using [gitleaks](https://github.com/gitleaks/gitleaks)
with the shared configuration in [`.gitleaks.toml`](.gitleaks.toml):

| Layer | Where | What it does |
| --- | --- | --- |
| Pre-commit hook | `.githooks/pre-commit` | Scans staged changes and blocks the commit on a finding |
| Pre-push hook | `.githooks/pre-push` | Scans every commit about to be pushed |
| CI | `.github/workflows/security.yml` | Scans the full git history on push, pull request, weekly schedule, and manual dispatch |

The configuration extends gitleaks' default ruleset and adds a rule that flags
plaintext Kubernetes `Secret` manifests. Encrypted values (SOPS) and sealed
secrets are allowed. Use SOPS or SealedSecrets rather than committing raw
secrets.

The CI workflow pins its action by commit SHA and verifies the gitleaks
download against a SHA-256 checksum. Dependabot keeps GitHub Actions
dependencies up to date.

## Getting started

Install gitleaks and enable the repository's hooks:

```sh
brew install gitleaks
git config core.hooksPath .githooks
```

The hooks refuse to run (and block the commit or push) if gitleaks is not
installed.

To scan the working repository manually:

```sh
gitleaks git --config .gitleaks.toml --redact
```

## Ignore rules

`.gitignore` excludes common sensitive and generated files, including
environment files, private keys, cloud credentials, kubeconfigs, Terraform
state and variable files, and build output. Files such as `.env.example` and
`*.tfvars.example` are explicitly kept.
