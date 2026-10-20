module "eks" {
  source = "../../modules/aws/eks"

  cluster_name         = "multiplayer-demo"
  admin_cidrs          = var.admin_cidrs
  admin_principal_arns = var.admin_principal_arns
}
