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
