module "aks" {
  source = "../../modules/azure/aks"

  location               = "eastus"
  cluster_name           = "multiplayer-demo"
  admin_cidrs            = var.admin_cidrs
  admin_group_object_ids = var.admin_group_object_ids
}
