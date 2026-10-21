# Starts with local state: the bucket this module creates does not exist until the
# first apply. After that, replace the local backend with the gcs block below and run
# `terraform init -migrate-state` (see README.md, step 3).
terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }

  # backend "gcs" {
  #   bucket = "multiplayer-demo-tfstate"
  #   prefix = "bootstrap/gcp-state-bucket"
  # }
}
