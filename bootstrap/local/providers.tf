provider "google" {
  # Uses the operator's Application Default Credentials (gcloud auth application-default login).
  project = var.gcp_project_id

  # Every resource that supports labels carries these.
  default_labels = {
    repo       = "gitops-pipeline"
    managed-by = "opentofu"
  }
}

# AWS and Azure are off unless enabled. While off, the providers skip every call that
# needs credentials, so a hub without those clouds plans and applies without a login.
provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = !var.aws_enabled
  skip_requesting_account_id  = !var.aws_enabled
  skip_metadata_api_check     = !var.aws_enabled

  default_tags {
    tags = {
      repo       = "gitops-pipeline"
      managed-by = "opentofu"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id                 = coalesce(var.azure_subscription_id, "00000000-0000-0000-0000-000000000000")
  resource_provider_registrations = "none"
}

provider "helm" {
  kubernetes = {
    host                   = module.kind.endpoint
    client_certificate     = module.kind.client_certificate
    client_key             = module.kind.client_key
    cluster_ca_certificate = module.kind.cluster_ca_certificate
  }
}

provider "kubernetes" {
  host                   = module.kind.endpoint
  client_certificate     = module.kind.client_certificate
  client_key             = module.kind.client_key
  cluster_ca_certificate = module.kind.cluster_ca_certificate
}
