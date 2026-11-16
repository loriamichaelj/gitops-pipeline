variable "issuer_url" {
  description = "The hub cluster's public service-account issuer, https, no trailing slash. AWS fetches its discovery document and JWKS from it."
  type        = string
}

variable "audience" {
  description = "Audience that hub service-account tokens must carry. Registered as the OIDC provider's client ID."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "namespace" {
  description = "Only service accounts in this namespace may assume the roles."
  type        = string
  default     = "crossplane-system"
}

variable "workloads" {
  description = <<-EOT
    One IAM role per Crossplane provider family, keyed by the provider's Kubernetes
    service-account name. policy_arns are attached to the role; inline_policy is a
    JSON policy document stored on it.
  EOT
  type = map(object({
    role_name     = string
    policy_arns   = optional(list(string), [])
    inline_policy = optional(string)
  }))
}
