variable "name" {
  description = "kind cluster name. The kubeconfig context becomes kind-<name>."
  type        = string
}

variable "node_image" {
  description = "kindest/node image, pinned by digest."
  type        = string
}

variable "kubeconfig_path" {
  description = "Where to write the cluster's kubeconfig. Keep it out of ~/.kube/config and out of Git."
  type        = string
}

variable "oidc_issuer_url" {
  description = "Public HTTPS URL the cluster signs service-account tokens as, with no trailing slash. Null keeps kind's private issuer, which only GCP can use."
  type        = string
  default     = null

  validation {
    condition     = var.oidc_issuer_url == null ? true : can(regex("^https://[^/]+(/[^/]+)*$", var.oidc_issuer_url))
    error_message = "oidc_issuer_url must be an https URL without a trailing slash."
  }
}
