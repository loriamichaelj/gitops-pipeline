output "account_id" {
  value = data.aws_caller_identity.this.account_id
}

output "audience" {
  value = var.audience
}

output "role_arns" {
  description = "Kubernetes service-account name => IAM role ARN."
  value       = { for ksa, r in aws_iam_role.workload : ksa => r.arn }
}
