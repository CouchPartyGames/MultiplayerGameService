# AWS GitHub OIDC bootstrap

Lets GitHub Actions workflows in `CouchPartyGames/MultiplayerGameService` get short-lived AWS credentials without storing access keys in GitHub. It creates:

| Resource | Purpose |
| --- | --- |
| `aws_iam_openid_connect_provider.github` | Trusts tokens issued by `https://token.actions.githubusercontent.com` with audience `sts.amazonaws.com`. An account can hold only one provider per URL. |
| `aws_iam_role.github_actions` | The role workflows assume. Its trust policy accepts only tokens whose `sub` matches `repo:<github_org>/<github_repo>:<subject>` for a subject in `github_subjects`. |
| `aws_iam_role_policy.github_actions` | Inline policy built from `role_policy_statements`: what the workflows may do in the account. |

The provider and role set `prevent_destroy`, because removing them cuts every workflow off from the account.

## Apply

This is a bootstrap root module (see [Bootstrap](../../../README.md#bootstrap)): apply it once per account with your own administrator credentials, with local state. It is not an Atlantis project or CI matrix entry.

1. In `versions.tf`, replace `123456789012` with the target account ID.
2. Copy the example variables and set `role_policy_statements` to what your workflows need:

   ```bash
   cp terraform/bootstrap/aws/aws-github-oidc/terraform.tfvars.example terraform/bootstrap/aws/aws-github-oidc/terraform.tfvars
   ```

3. Plan and apply:

   ```bash
   terraform -chdir=terraform/bootstrap/aws/aws-github-oidc init
   terraform -chdir=terraform/bootstrap/aws/aws-github-oidc plan -out=tfplan
   terraform -chdir=terraform/bootstrap/aws/aws-github-oidc apply tfplan
   ```

4. Once the state bucket exists, add a `backend "s3"` block and run `init -migrate-state` to move this module's state into it.

If the account already has a GitHub OIDC provider, import it instead of creating a second one:

```bash
terraform -chdir=terraform/bootstrap/aws/aws-github-oidc import aws_iam_openid_connect_provider.github \
  arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `github_org` | `string` | `"CouchPartyGames"` | Owner of the repository allowed to assume the role. |
| `github_repo` | `string` | `"MultiplayerGameService"` | Repository name, without the owner. |
| `github_subjects` | `list(string)` | `["ref:refs/heads/main", "pull_request"]` | Subject suffixes allowed after `repo:<org>/<repo>:`, such as `environment:production`. `*` and `?` wildcards are allowed, but not a bare `*`. |
| `role_name` | `string` | `"github-actions"` | IAM role name. |
| `max_session_duration` | `number` | `3600` | Maximum session length in seconds (3600 to 43200). |
| `role_policy_statements` | `list(object)` | required | Inline policy statements: `sid`, `effect` (`Allow` by default), `actions`, `resources`. |

## Outputs

| Name | Description |
| --- | --- |
| `oidc_provider_arn` | GitHub OIDC provider ARN, for trust policies of other roles. |
| `role_arn` | Role ARN, for `role-to-assume` in workflows. |
| `role_name` | Role name. |

## Use it in a workflow

The job needs `id-token: write` to request an OIDC token:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/github-actions
      aws-region: us-east-1
  - run: aws sts get-caller-identity
```

Jobs that use a GitHub environment get the subject `environment:<name>` instead of `ref:...` or `pull_request`, so add that subject to `github_subjects`.

## Tests

```bash
terraform -chdir=terraform/bootstrap/aws/aws-github-oidc init -backend=false
terraform -chdir=terraform/bootstrap/aws/aws-github-oidc test
```
