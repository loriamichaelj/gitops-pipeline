variable "subscription_id" {
  description = "Subscription Crossplane manages."
  type        = string
}

variable "location" {
  description = "Region for the resource group that holds the managed identity."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  type    = string
  default = "gitops-pipeline-identity"
}

variable "identity_name" {
  type    = string
  default = "xp-azure-hub"
}

variable "issuer_url" {
  description = "The hub cluster's public service-account issuer, https, no trailing slash. Entra ID fetches its discovery document and JWKS from it."
  type        = string
}

variable "audience" {
  description = "Audience that hub service-account tokens must carry. Entra ID's fixed value."
  type        = string
  default     = "api://AzureADTokenExchange"
}

variable "namespace" {
  description = "Only service accounts in this namespace may federate."
  type        = string
  default     = "crossplane-system"
}

variable "service_accounts" {
  description = "Kubernetes service accounts of the provider families. Each gets a federated credential on the one identity."
  type        = list(string)
}

variable "actions" {
  description = "Management-plane actions the identity may perform on the subscription, as one custom role. It grants no role-assignment or policy rights."
  type        = list(string)
}

variable "roles" {
  description = "Extra built-in roles to assign on the subscription. Empty by default: the custom role is enough."
  type        = list(string)
  default     = []
}
