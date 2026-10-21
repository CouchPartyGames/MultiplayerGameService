output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider, for trust policies of other roles GitHub Actions should assume."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "role_arn" {
  description = "ARN of the GitHub Actions role, for the `role-to-assume` input of aws-actions/configure-aws-credentials."
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Name of the GitHub Actions role."
  value       = aws_iam_role.github_actions.name
}
