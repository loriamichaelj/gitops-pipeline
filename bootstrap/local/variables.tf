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
