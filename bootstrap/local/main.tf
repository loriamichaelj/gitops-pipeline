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

  aws_enabled   = var.aws_enabled
  azure_enabled = var.azure_subscription_id != null

  # One IAM role per provider family, as for GCP. The managed policies are the broad
  # service policies; narrow them with an inline policy once the resources are known.
  aws_workloads = {
    "provider-aws-s3" = {
      role_name   = "xp-aws-s3-${var.env}"
      policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
    }
    "provider-aws-ec2" = {
      role_name   = "xp-aws-ec2-${var.env}"
      policy_arns = ["arn:aws:iam::aws:policy/AmazonVPCFullAccess"]
    }
  }

  # Azure's ClusterProviderConfig holds one client ID, so the families share an
  # identity and each service account gets a federated credential on it.
  azure_service_accounts = ["provider-azure-storage", "provider-azure-network", "provider-azure-resources"]
}

check "issuer_for_aws_and_azure" {
  assert {
    condition     = (!local.aws_enabled && !local.azure_enabled) || var.oidc_issuer_url != null
    error_message = "AWS and Azure fetch the hub's keys over public HTTPS: set oidc_issuer_url (see the README) before enabling either."
  }
}

module "kind" {
  source = "../modules/kind-cluster"

  name            = var.cluster_name
  node_image      = var.node_image
  kubeconfig_path = "${path.module}/${var.cluster_name}.kubeconfig" # gitignored (*.kubeconfig)
  oidc_issuer_url = var.oidc_issuer_url
}

# The files a public host must serve at oidc_issuer_url, for AWS and Azure to trust the
# hub. Public signing keys only. Gitignored: they change whenever the cluster is recreated.
resource "local_file" "oidc_discovery" {
  count = var.oidc_issuer_url == null ? 0 : 1

  filename = "${path.module}/oidc/.well-known/openid-configuration"
  content  = module.kind.oidc_discovery
}

resource "local_file" "oidc_jwks" {
  count = var.oidc_issuer_url == null ? 0 : 1

  filename = "${path.module}/oidc/openid/v1/jwks"
  content  = module.kind.oidc_jwks
}

# Stops GitHub Pages from running Jekyll, which would drop the .well-known directory.
resource "local_file" "oidc_nojekyll" {
  count = var.oidc_issuer_url == null ? 0 : 1

  filename = "${path.module}/oidc/.nojekyll"
  content  = ""
}

module "aws_identity" {
  source = "../modules/aws-identity"
  count  = local.aws_enabled ? 1 : 0

  issuer_url = var.oidc_issuer_url
  namespace  = "crossplane-system"
  workloads  = local.aws_workloads
}

module "azure_identity" {
  source = "../modules/azure-identity"
  count  = local.azure_enabled ? 1 : 0

  subscription_id  = var.azure_subscription_id
  location         = var.azure_location
  issuer_url       = var.oidc_issuer_url
  service_accounts = local.azure_service_accounts
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
    role             = "hub"
    env              = var.env
    cloud            = "kind"
    "gcp-identity"   = local.gcp_enabled ? "federated" : "none"
    "aws-identity"   = local.aws_enabled ? "federated" : "none"
    "azure-identity" = local.azure_enabled ? "federated" : "none"
  }

  cluster_annotations = merge(
    local.gcp_enabled ? merge(
      {
        "${local.fact_prefix}/project-id"     = module.gcp_identity[0].project_id
        "${local.fact_prefix}/project-number" = module.gcp_identity[0].project_number
        "${local.fact_prefix}/wif-provider"   = module.gcp_identity[0].wif_provider
        "${local.fact_prefix}/audience"       = module.gcp_identity[0].audience
      },
      { for ksa, email in module.gcp_identity[0].service_accounts : "${local.fact_prefix}/sa.${ksa}" => email },
    ) : {},
    local.aws_enabled ? merge(
      {
        "aws.gitops-pipeline/account-id" = module.aws_identity[0].account_id
        "aws.gitops-pipeline/audience"   = module.aws_identity[0].audience
      },
      { for ksa, arn in module.aws_identity[0].role_arns : "aws.gitops-pipeline/role.${ksa}" => arn },
    ) : {},
    local.azure_enabled ? {
      "azure.gitops-pipeline/tenant-id"       = module.azure_identity[0].tenant_id
      "azure.gitops-pipeline/subscription-id" = module.azure_identity[0].subscription_id
      "azure.gitops-pipeline/client-id"       = module.azure_identity[0].client_id
      "azure.gitops-pipeline/audience"        = module.azure_identity[0].audience
    } : {},
  )
}
