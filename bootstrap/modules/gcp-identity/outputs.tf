output "project_id" {
  value = var.project_id
}

output "project_number" {
  value = data.google_project.this.number
}

output "wif_provider" {
  description = "Full resource name: projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<provider>."
  value       = google_iam_workload_identity_pool_provider.hub.name
}

output "audience" {
  value = var.audience
}

output "service_accounts" {
  description = "Kubernetes service-account name => GCP service-account email."
  value       = { for ksa, sa in google_service_account.workload : ksa => sa.email }
}
