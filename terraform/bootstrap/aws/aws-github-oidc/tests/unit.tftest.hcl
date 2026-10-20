# Unit tests with a mocked AWS provider: no credentials needed, no resources created.
# Run with `terraform -chdir=terraform/bootstrap/aws/aws-github-oidc test`.

mock_provider "aws" {
  # The trust policy needs a real-looking ARN; the mock otherwise returns a random string.
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  # Mocked data sources return a random string as json, which the IAM resources reject.
  # The statement blocks still come from the real inputs, so the tests check those.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  role_policy_statements = [
    {
      sid       = "ReadState"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::multiplayer-demo-tfstate-123456789012/*"]
    },
  ]
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "The OIDC provider should point at GitHub's token issuer."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github.client_id_list == toset(["sts.amazonaws.com"])
    error_message = "The OIDC provider audience should be sts.amazonaws.com."
  }

  assert {
    condition     = aws_iam_role.github_actions.name == "github-actions" && aws_iam_role.github_actions.max_session_duration == 3600
    error_message = "The role should default to github-actions with a one-hour session."
  }

  assert {
    condition     = aws_iam_role_policy.github_actions.name == "github-actions-permissions"
    error_message = "The inline policy should be named after the role."
  }

  assert {
    condition = toset([for c in data.aws_iam_policy_document.trust.statement[0].condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"][0]) == toset([
      "repo:CouchPartyGames/MultiplayerGameService:ref:refs/heads/main",
      "repo:CouchPartyGames/MultiplayerGameService:pull_request",
    ])
    error_message = "The trust policy should allow only main and pull requests of this repository."
  }
}

run "custom_subjects" {
  command = plan

  variables {
    github_org      = "example"
    github_repo     = "game"
    github_subjects = ["environment:production"]
  }

  assert {
    condition     = toset([for c in data.aws_iam_policy_document.trust.statement[0].condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"][0]) == toset(["repo:example/game:environment:production"])
    error_message = "The trust policy subject should be built from the org, repo, and subject suffix."
  }
}

run "rejects_wildcard_subject" {
  command = plan

  variables {
    github_subjects = ["*"]
  }

  expect_failures = [var.github_subjects]
}

run "rejects_empty_policy" {
  command = plan

  variables {
    role_policy_statements = []
  }

  expect_failures = [var.role_policy_statements]
}

run "rejects_invalid_effect" {
  command = plan

  variables {
    role_policy_statements = [
      {
        sid       = "Bad"
        effect    = "allow"
        actions   = ["s3:GetObject"]
        resources = ["*"]
      },
    ]
  }

  expect_failures = [var.role_policy_statements]
}
