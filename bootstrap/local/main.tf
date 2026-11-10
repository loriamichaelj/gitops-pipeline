locals {
  gcp_enabled = var.gcp_project_id != null

  # One GCP service account per Crossplane provider family (least privilege).
  # Keys are the provider pods' Kubernetes service-account names, which the
  # DeploymentRuntimeConfigs in platform/crossplane/providers/gcp set explicitly.
  gcp_workloads = {
    "provider-gcp-storage" = {
      gsa_id = "xp-gcp-storage-${var.env}"
      roles  = ["roles/storage.admin"]
    }
    "provider-gcp-compute" = {
      gsa_id = "xp-gcp-compute-${var.env}"
      roles  = ["roles/compute.networkAdmin"]
    }
  }

  fact_prefix = "gcp.gitops-pipeline"
}

module "kind" {
  source = "../modules/kind-cluster"

  name            = var.cluster_name
  node_image      = var.node_image
  kubeconfig_path = "${path.module}/${var.cluster_name}.kubeconfig" # gitignored (*.kubeconfig)
}

module "gcp_identity" {
  source = "../modules/gcp-identity"
  count  = local.gcp_enabled ? 1 : 0

  project_id  = var.gcp_project_id
  pool_id     = var.gcp_pool_id
  provider_id = var.cluster_name
  issuer_uri  = module.kind.oidc_issuer
  jwks_json   = module.kind.oidc_jwks
  workloads   = local.gcp_workloads
}

module "argocd" {
  source = "../modules/argocd"

  chart_version      = var.argocd_chart_version
  apps_chart_version = var.argocd_apps_chart_version
  values_file        = "${path.module}/../../platform/argocd/values.yaml"
  repo_url           = var.repo_url
  target_revision    = var.target_revision

  root_values = {
    env = var.env
    argocd = {
      chartVersion = var.argocd_chart_version
    }
  }

  cluster_labels = {
    role           = "hub"
    env            = var.env
    cloud          = "kind"
    "gcp-identity" = local.gcp_enabled ? "federated" : "none"
  }

  cluster_annotations = local.gcp_enabled ? merge(
    {
      "${local.fact_prefix}/project-id"     = module.gcp_identity[0].project_id
      "${local.fact_prefix}/project-number" = module.gcp_identity[0].project_number
      "${local.fact_prefix}/wif-provider"   = module.gcp_identity[0].wif_provider
      "${local.fact_prefix}/audience"       = module.gcp_identity[0].audience
    },
    { for ksa, email in module.gcp_identity[0].service_accounts : "${local.fact_prefix}/sa.${ksa}" => email },
  ) : {}
}
