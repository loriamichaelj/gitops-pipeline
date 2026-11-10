locals {
  apis = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
    "compute.googleapis.com",
  ]

  role_bindings = merge([
    for ksa, w in var.workloads : {
      for role in w.roles : "${ksa}/${role}" => { ksa = ksa, role = role }
    }
  ]...)
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_iam_workload_identity_pool" "hub" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "gitops-pipeline hub"
  description               = "Kubernetes service accounts on the gitops-pipeline hub cluster."

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "hub" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.hub.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "hub cluster"

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }
  attribute_condition = "assertion.sub.startsWith('system:serviceaccount:${var.namespace}:')"

  oidc {
    issuer_uri        = var.issuer_uri
    jwks_json         = var.jwks_json
    allowed_audiences = [var.audience]
  }
}

resource "google_service_account" "workload" {
  for_each = var.workloads

  project      = var.project_id
  account_id   = each.value.gsa_id
  display_name = "Crossplane ${each.key}"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "workload" {
  for_each = local.role_bindings

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.workload[each.value.ksa].email}"
}

# Only the matching Kubernetes service account may impersonate each GCP service account.
resource "google_service_account_iam_member" "federation" {
  for_each = var.workloads

  service_account_id = google_service_account.workload[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.hub.name}/subject/system:serviceaccount:${var.namespace}:${each.key}"
}
