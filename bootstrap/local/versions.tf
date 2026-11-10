terraform {
  required_version = ">= 1.10"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.13.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.4"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
  }

  # Local state: this hub is disposable and the state holds only kind client
  # certificates and GCP resource names. *.tfstate is gitignored.
}
