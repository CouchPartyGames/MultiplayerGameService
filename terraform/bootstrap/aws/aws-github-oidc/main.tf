# GitHub Actions OIDC federation: workflows in the allowed repo and refs exchange
# their OIDC token for short-lived credentials on the role below, so no AWS access
# keys are stored in GitHub. Every resource sets prevent_destroy: removing them cuts
# CI off from the account.

locals {
  oidc_host = "token.actions.githubusercontent.com"
  repo_sub  = "repo:${var.github_org}/${var.github_repo}"
}

# AWS validates GitHub's certificate against its own trusted root CAs, so no
# thumbprint_list is needed (AWS provider 5.81+ makes it optional).
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  lifecycle {
    prevent_destroy = true
  }
}


data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Pin the token's subject to this repo; without it any GitHub repo could assume the role.
    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = [for s in var.github_subjects : "${local.repo_sub}:${s}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = var.role_name
  description          = "Assumed by GitHub Actions in ${var.github_org}/${var.github_repo} through OIDC."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "permissions" {
  dynamic "statement" {
    for_each = var.role_policy_statements

    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.role_name}-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.permissions.json
}
