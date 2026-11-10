# The bucket name is passed at init (-backend-config=bucket=...) so it stays out
# of Git. The first run uses a local backend instead; see README.md.
terraform {
  backend "gcs" {
    prefix = "seed"
  }
}
