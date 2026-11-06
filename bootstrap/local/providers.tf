provider "google" {
  # Uses the operator's Application Default Credentials (gcloud auth application-default login).
  project = var.gcp_project_id
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
