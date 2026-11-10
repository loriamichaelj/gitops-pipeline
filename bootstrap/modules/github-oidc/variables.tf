variable "project_id" {
  type = string
}

variable "pool_id" {
  description = "Workload identity pool ID. Deleted pools are soft-deleted for 30 days, so a recreated pool needs a new ID."
  type        = string
  default     = "github-actions"
}

variable "provider_id" {
  type    = string
  default = "github"
}

variable "repository" {
  description = "owner/name, used in the token subject."
  type        = string
}

variable "repository_id" {
  description = "Numeric GitHub repository ID."
  type        = string
}

variable "repository_owner_id" {
  description = "Numeric GitHub owner ID."
  type        = string
}

variable "environments" {
  description = "One service account per GitHub environment, keyed by environment name."
  type = map(object({
    account_id    = string
    project_roles = list(string)
  }))
}
