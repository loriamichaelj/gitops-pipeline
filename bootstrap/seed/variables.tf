variable "project_id" {
  description = "GCP project that hosts the state bucket and the GitHub identity pool."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "repository" {
  description = "GitHub repository (owner/name) whose workflows are trusted."
  type        = string
  default     = "loriamichaelj/gitops-pipeline"
}

variable "repository_id" {
  description = "Numeric GitHub repository ID (gh api repos/<owner>/<name> -q .id)."
  type        = string
}

variable "repository_owner_id" {
  description = "Numeric GitHub owner ID (gh api repos/<owner>/<name> -q .owner.id)."
  type        = string
}
