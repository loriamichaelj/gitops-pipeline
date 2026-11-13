locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]

  state_bucket = "${var.project_id}-tfstate"

  # One identity per GitHub environment. Branch and approval rules live on the
  # environments themselves; these roles bound what each can do once it runs.
  environments = {
    # Pull-request checks: plan only, read access.
    ci = {
      account_id = "gha-ci"
      project_roles = [
        "roles/viewer",
        "roles/iam.securityReviewer", # read IAM policies, which plan refreshes
      ]
    }

    # Maintains this module: identity pool, service accounts, bindings, the state
    # bucket. Powerful (it can grant roles), hence the approval gate on the
    # environment.
    seed = {
      account_id = "gha-seed"
      project_roles = [
        "roles/iam.workloadIdentityPoolAdmin",
        "roles/iam.serviceAccountAdmin",
        "roles/resourcemanager.projectIamAdmin",
        "roles/serviceusage.serviceUsageAdmin",
        "roles/storage.admin",
      ]
    }

    # Reads and writes only its own state prefix (below). No project roles: nothing
    # in the repository reads cloud resources. Add roles with the stack that needs them.
    dev = {
      account_id    = "gha-dev"
      project_roles = []
    }
  }
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "state_bucket" {
  source = "../modules/state-bucket"

  project_id = var.project_id
  name       = local.state_bucket
  location   = var.region
  labels = {
    purpose    = "tofu-state"
    managed-by = "opentofu"
    repo       = "gitops-pipeline"
  }

  depends_on = [google_project_service.apis]
}

module "github_oidc" {
  source = "../modules/github-oidc"

  project_id          = var.project_id
  repository          = var.repository
  repository_id       = var.repository_id
  repository_owner_id = var.repository_owner_id
  environments        = local.environments

  depends_on = [google_project_service.apis]
}

# seed manages the bucket itself (roles/storage.admin above). ci reads state to
# plan; dev reads and writes only under its own prefix, so it cannot tamper with
# the state that seed later applies.
resource "google_storage_bucket_iam_member" "ci_read" {
  bucket = module.state_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.github_oidc.service_accounts["ci"]}"
}

resource "google_storage_bucket_iam_member" "dev_state" {
  bucket = module.state_bucket.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${module.github_oidc.service_accounts["dev"]}"

  condition {
    title      = "dev-state-prefix"
    expression = "resource.name.startsWith(\"projects/_/buckets/${module.state_bucket.name}/objects/dev/\")"
  }
}
