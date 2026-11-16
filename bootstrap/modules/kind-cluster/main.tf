resource "kind_cluster" "this" {
  name            = var.name
  node_image      = var.node_image
  kubeconfig_path = var.kubeconfig_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # With a public issuer URL the API server signs tokens as that issuer and
      # advertises its JWKS there. AWS and Azure fetch both over HTTPS, unlike GCP,
      # which accepts an uploaded copy. Changing it means recreating the cluster.
      kubeadm_config_patches = var.oidc_issuer_url == null ? null : [yamlencode({
        kind = "ClusterConfiguration"
        apiServer = {
          extraArgs = {
            "service-account-issuer"   = var.oidc_issuer_url
            "service-account-jwks-uri" = "${var.oidc_issuer_url}/openid/v1/jwks"
          }
        }
      })]
    }
  }
}

# The service-account issuer and its public signing keys. GCP Workload Identity
# Federation trusts tokens from this cluster by holding a copy of the JWKS.
# Reading at apply time (the query depends on the cluster endpoint)
# means a recreated cluster's new keys are picked up in the same apply.
data "external" "oidc" {
  program = ["bash", "${path.module}/oidc.sh"]

  query = {
    kubeconfig = kind_cluster.this.kubeconfig_path
    context    = "kind-${var.name}"
    endpoint   = kind_cluster.this.endpoint
  }
}
