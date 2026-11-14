# gitops-pipeline

A GitOps platform for multi-cloud infrastructure. A local kind cluster (the
"hub") runs Argo CD and Crossplane. You declare cloud resources as YAML under
`infrastructure/`. Argo CD syncs them to the hub, and Crossplane Compositions
create the cloud resources.

The repository deploys nothing by default. Every API has a Composition for GCP,
AWS and Azure, each tested and checked against the real provider schemas. Only the
GCP providers and identity are wired into the hub, so GCP is the only cloud a hub
can deploy to today. See [platform/apis/README.md](platform/apis/README.md) for what
each cloud creates and what enabling AWS or Azure on a hub takes.

## How a change reaches the cloud

```
PR to dev ──► CI: validate, scan, security
   │ merge
   ▼
Argo CD on the hub (app-of-apps chart: platform/argocd/root)
   │  one Application per infrastructure/<env>/<cloud>, only on hubs whose
   │  cluster Secret carries <cloud>-identity=federated
   ▼
XRs (XBucket, XNetwork) in infra-<env> ──► Compositions (KCL, function-kcl)
   ▼
Crossplane GCP providers, one per family, each authenticating by workload
identity federation (no keys)
   ▼
GCP resources
```

The root chart orders the rollout with sync waves: namespaces and AppProjects,
then Argo CD itself, Crossplane, functions and providers, platform APIs (XRDs and
Compositions), and finally `infrastructure/`.

## Platform APIs

| Kind | Parameters | GCP | AWS | Azure |
|---|---|---|---|---|
| `XBucket` | `location`, `storageClass`, `versioning`, `forceDestroy`, `deletionPolicy`, `owner` | Private GCS bucket | Private S3 bucket | Private Blob container in its own storage account |
| `XNetwork` | `region`, `cidr`, `podsCidr` + `servicesCidr` (GKE only, set together), `deletionPolicy` | Custom-mode VPC, one subnet | VPC, one private subnet | Virtual network, one subnet |

Some parameters mean different things per cloud, and a few are refused where a
cloud has no equivalent. The table in
[platform/apis/README.md](platform/apis/README.md#parameters-by-cloud) lists them.

Cloud names are deterministic (`<namespace>-<name>-<hash>`), so a rebuilt hub
adopts existing resources instead of creating new ones. AWS VPCs and subnets are
the exception: AWS assigns their IDs. Setting `deletionPolicy: Orphan` keeps the
cloud resource when the XR is deleted.

A claim picks its cloud with a `compositionSelector`. This is an example for
`infrastructure/<env>/<cloud>/`; no claim is checked in:

```yaml
apiVersion: platform.gitops-pipeline.io/v1alpha1
kind: XBucket
metadata:
  name: artifacts
  namespace: infra-dev
spec:
  crossplane:
    compositionSelector:
      matchLabels:
        cloud: gcp
  parameters:
    location: US-CENTRAL1
```

## Layout

| Path | Contents |
|---|---|
| `infrastructure/<env>/<cloud>/` | The XRs the hub reconciles (none checked in; see [infrastructure/README.md](infrastructure/README.md)) |
| `platform/apis/` | XRDs and per-cloud Compositions |
| `platform/argocd/root/` | App-of-apps Helm chart: pinned chart versions, environments, clouds |
| `platform/crossplane/` | Crossplane install values, composition functions, GCP provider chart, AWS and Azure packages for schema checks only |
| `platform/policies/` | Kyverno policies for what may live in `infrastructure/` |
| `bootstrap/local/` | OpenTofu: kind hub, Argo CD, GCP workload identity for the providers |
| `bootstrap/seed/` | OpenTofu: state bucket and GitHub OIDC identities ([README](bootstrap/seed/README.md)) |
| `scripts/` | Every check and tool; the Makefile and CI both call these |
| `tests/` | Composition snapshot tests and Kyverno policy tests |

## Getting started

Install gitleaks and enable the repository's hooks:

```sh
brew install gitleaks
git config core.hooksPath .githooks
```

The hooks refuse to run (and block the commit or push) if gitleaks is not
installed. To scan the repository manually:

```sh
gitleaks git --config .gitleaks.toml --redact
```

### Run the checks

`make validate` runs the same checks as CI. It needs helm, yq, kubeconform,
crossplane, kyverno, tofu, trivy and docker (composition functions run in
containers).

| Target | What it does |
|---|---|
| `make render` | `helm template` every source the hub syncs into `rendered/` |
| `make compositions` | Snapshot-test the Compositions |
| `make schemas` | kubeconform plus `crossplane resource validate` |
| `make policies` | Kyverno tests, then the policies against each `infrastructure/` folder |
| `make tofu` | `tofu fmt -check` and `tofu validate` for every root under `bootstrap/` |
| `make scan` | trivy and checkov |
| `make update-snapshots` | Rewrite the expected snapshots (review the diff) |

### Bring up a hub

```sh
cd bootstrap/local
cp terraform.tfvars.example terraform.tfvars   # gcp_project_id; leave it unset for a hub without cloud access
tofu init && tofu apply
export KUBECONFIG=$(tofu output -raw kubeconfig)
```

`tofu output argocd_ui` and `tofu output argocd_admin_password` print the
commands for reaching the Argo CD UI. To test a feature branch on the hub before
opening a PR, set `target_revision` in `terraform.tfvars`.

## Workflow

Infrastructure changes go through a pull request to `dev`. After merge, Argo CD
and Crossplane apply the change. CI reaches GCP only by OIDC federation, with one
service account per GitHub environment (`ci`, `seed`, `dev`). The `seed` workflow
maintains those identities.
