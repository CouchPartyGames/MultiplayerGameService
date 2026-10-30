terraform {
  backend "gcs" {
    bucket = "terraform-state"
    prefix = "root-module"
  }
}
