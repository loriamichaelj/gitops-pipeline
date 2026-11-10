resource "google_storage_bucket" "state" {
  # checkov:skip=CKV_GCP_62: Admin Activity audit logs already record changes to the bucket and its IAM. Usage logs would need a second bucket to hold them.
  project  = var.project_id
  name     = var.name
  location = var.location

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  # State history is the recovery path for a bad apply; keep a bounded amount.
  lifecycle_rule {
    condition {
      num_newer_versions = var.keep_versions
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels

  lifecycle {
    prevent_destroy = true
  }
}
