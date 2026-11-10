locals {
  # GitHub's immutable subject format embeds the numeric IDs:
  #   repo:<owner>@<owner_id>/<name>@<repository_id>:environment:<env>
  # It is the default for new repositories (see the repo's OIDC customization).
  repo_owner  = split("/", var.repository)[0]
  repo_name   = split("/", var.repository)[1]
  subject_for = "repo:${local.repo_owner}@${var.repository_owner_id}/${local.repo_name}@${var.repository_id}"

  project_roles = merge([
    for env, cfg in var.environments : {
      for role in cfg.project_roles : "${env}/${role}" => { env = env, role = role }
    }
  ]...)
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "GitHub Actions jobs of ${var.repository}, one service account per environment."
}

# Trusts GitHub's OIDC tokens, but only those minted for this repository. The
# immutable numeric IDs are checked, not the names: a renamed, deleted or
# recreated repository cannot inherit access.
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.environment"      = "assertion.environment"
    "attribute.ref"              = "assertion.ref"
    "attribute.job_workflow_ref" = "assertion.job_workflow_ref"
  }
  attribute_condition = "assertion.repository_id == '${var.repository_id}' && assertion.repository_owner_id == '${var.repository_owner_id}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "environment" {
  for_each = var.environments

  project      = var.project_id
  account_id   = each.value.account_id
  display_name = "GitHub Actions: ${each.key} environment"
}

resource "google_project_iam_member" "environment" {
  for_each = local.project_roles

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.environment[each.value.env].email}"
}

# A job may impersonate an environment's service account only when it runs in
# that GitHub environment, whose branch and approval rules then apply. The
# subject embeds the numeric IDs, so a renamed or recreated repository does not
# match.
resource "google_service_account_iam_member" "federation" {
  for_each = var.environments

  service_account_id = google_service_account.environment[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${local.subject_for}:environment:${each.key}"
}
