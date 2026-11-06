# gitops-pipeline

A GitOps pipeline project for multi-cloud infrastructure and delivery.

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
