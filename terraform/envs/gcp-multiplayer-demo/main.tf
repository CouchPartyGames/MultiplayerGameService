locals {
  project_id = "multiplayer-demo"
  region     = "us-east1"
  zone       = "us-east1-b"
}

module "gke" {
  source = "../../modules/gcp/gke"

  project_id   = local.project_id
  region       = local.region
  zone         = local.zone
  cluster_name = "multiplayer-demo"
  admin_cidrs  = var.admin_cidrs
}
