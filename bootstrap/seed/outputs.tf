# These feed the GitHub environments' secrets (see README.md).
output "project_id" {
  value = var.project_id
}

output "state_bucket" {
  value = module.state_bucket.name
}

output "workload_identity_provider" {
  value = module.github_oidc.provider
}

output "service_accounts" {
  description = "GitHub environment => service account email."
  value       = module.github_oidc.service_accounts
}
