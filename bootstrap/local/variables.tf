variable "gcp_project_id" {
  description = "GCP project for Crossplane. Leave null to bring up the hub without cloud access."
  type        = string
  default     = null
}

variable "cluster_name" {
  type    = string
  default = "gitops-hub"
}

variable "node_image" {
  description = "Default node image for kind v0.33.0."
  type        = string
  default     = "kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/loriamichaelj/gitops-pipeline.git"
}

variable "target_revision" {
  description = "Branch the hub reconciles. Point it at a feature branch to test before opening a PR."
  type        = string
  default     = "dev"
}

variable "env" {
  type    = string
  default = "local"
}

variable "argocd_chart_version" {
  description = "argo-cd chart 10.11.1 = Argo CD v3.5.6."
  type        = string
  default     = "10.11.1"
}

variable "argocd_apps_chart_version" {
  type    = string
  default = "2.0.7"
}

variable "gcp_pool_id" {
  description = "WIF pool ID. Change it if the pool was deleted in the last 30 days."
  type        = string
  default     = "gitops-hub-local"
}

variable "oidc_issuer_url" {
  description = <<-EOT
    Public HTTPS URL the hub signs service-account tokens as, with no trailing slash,
    for example https://<owner>.github.io/<repo>/oidc/<cluster_name>. Required for AWS
    and Azure, which fetch the discovery document and keys from it; GCP does not need
    it. Changing it recreates the cluster. After apply, publish ./oidc (see README).
  EOT
  type        = string
  default     = null
}

variable "aws_enabled" {
  description = "Create the AWS identity (IAM OIDC provider and one role per provider family). Needs oidc_issuer_url and AWS credentials."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "Region for the AWS provider. IAM is global; this only picks the API endpoint."
  type        = string
  default     = "us-east-1"
}

variable "azure_subscription_id" {
  description = "Azure subscription for Crossplane. Leave null for no Azure identity. Needs oidc_issuer_url and an Azure login."
  type        = string
  default     = null
}

variable "azure_location" {
  description = "Region of the resource group that holds the managed identity."
  type        = string
  default     = "eastus"
}
