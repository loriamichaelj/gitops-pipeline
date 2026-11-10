variable "chart_version" {
  description = "argo-cd Helm chart version. Passed to the root chart too, so Argo CD manages itself at the same version."
  type        = string
}

variable "apps_chart_version" {
  description = "argocd-apps Helm chart version, used only to create the root Application."
  type        = string
}

variable "values_file" {
  description = "Path to the Argo CD values file shared with the self-managed Application."
  type        = string
}

variable "repo_url" {
  description = "Git repository Argo CD reconciles from."
  type        = string
}

variable "target_revision" {
  description = "Branch, tag or commit the root Application tracks."
  type        = string
}

variable "root_values" {
  description = "Extra Helm values for the root chart (merged over repoURL/targetRevision)."
  type        = any
  default     = {}
}

variable "cluster_labels" {
  description = "Labels on the hub's Argo CD cluster Secret. ApplicationSet cluster generators select on these."
  type        = map(string)
}

variable "cluster_annotations" {
  description = "Environment facts on the hub's Argo CD cluster Secret. Never secret values."
  type        = map(string)
  default     = {}
}
