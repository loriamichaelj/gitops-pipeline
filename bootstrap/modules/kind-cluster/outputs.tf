output "endpoint" {
  value = kind_cluster.this.endpoint
}

output "client_certificate" {
  value = kind_cluster.this.client_certificate
}

output "client_key" {
  value     = kind_cluster.this.client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value = kind_cluster.this.cluster_ca_certificate
}

output "kubeconfig_path" {
  value = kind_cluster.this.kubeconfig_path
}

output "context" {
  value = "kind-${var.name}"
}

output "oidc_issuer" {
  description = "Service-account token issuer (iss claim)."
  value       = data.external.oidc.result.issuer
}

output "oidc_jwks" {
  description = "Public signing keys for service-account tokens, as a JSON string."
  value       = data.external.oidc.result.jwks
}
