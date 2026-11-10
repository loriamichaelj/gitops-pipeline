output "provider" {
  description = "Full provider resource name, as the auth action's workload_identity_provider."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_accounts" {
  description = "GitHub environment => service account email."
  value       = { for env, sa in google_service_account.environment : env => sa.email }
}
