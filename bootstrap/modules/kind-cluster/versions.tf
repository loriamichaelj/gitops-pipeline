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
  }
}
