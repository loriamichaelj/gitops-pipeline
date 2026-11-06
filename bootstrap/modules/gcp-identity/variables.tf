variable "project_id" {
  description = "GCP project that Crossplane manages and that hosts the identity pool."
  type        = string
}

variable "pool_id" {
  description = "Workload identity pool ID. Deleted pools are soft-deleted for 30 days, so a recreated pool needs a new ID."
  type        = string
}

variable "provider_id" {
  description = "Workload identity pool provider ID."
  type        = string
}

variable "issuer_uri" {
  description = "The hub cluster's service-account token issuer."
  type        = string
}

variable "jwks_json" {
  description = "The hub cluster's JWKS. Set for clusters whose issuer is not publicly reachable (kind); null to let GCP fetch it."
  type        = string
  default     = null
}

variable "audience" {
  description = "Audience that hub service-account tokens must carry."
  type        = string
  default     = "gitops-pipeline-hub"
}

variable "namespace" {
  description = "Only service accounts in this namespace may federate."
  type        = string
  default     = "crossplane-system"
}

variable "workloads" {
  description = <<-EOT
    One GCP service account per Crossplane provider family, keyed by the provider's
    Kubernetes service-account name. gsa_id is the GCP account ID (6-30 chars).
  EOT
  type = map(object({
    gsa_id = string
    roles  = list(string)
  }))
}
