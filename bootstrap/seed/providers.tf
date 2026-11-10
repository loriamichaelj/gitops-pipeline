provider "google" {
  project = var.project_id
  region  = var.region

  # Every resource that supports labels carries these.
  default_labels = {
    repo       = "gitops-pipeline"
    managed-by = "opentofu"
  }
}
