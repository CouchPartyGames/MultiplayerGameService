output "vpc_id" {
  description = "Created VPC ID."
  value       = aws_vpc.eks.id
}

output "public_subnet_ids" {
  description = "Public subnets for internet-facing load balancers and NAT gateways."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnets used by EKS nodes."
  value       = aws_subnet.private[*].id
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = aws_eks_cluster.eks.endpoint
}

output "node_role_arn" {
  description = "IAM role used by managed nodes."
  value       = aws_iam_role.nodes.arn
}

output "get_credentials_command" {
  description = "Run with credentials for a configured administrator principal (or add --role-arn for an assumable administrator role)."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.eks.name}"
}
