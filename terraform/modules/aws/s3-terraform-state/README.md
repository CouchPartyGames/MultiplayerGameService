# s3-terraform-state

Creates the S3 bucket, and optionally the DynamoDB lock table, that a Terraform S3 backend stores state in. Apply it once per AWS account from a bootstrap configuration with local state, then point other configurations' `backend "s3"` blocks at its outputs.

| Resource | Settings |
| --- | --- |
| `aws_s3_bucket.state` | `prevent_destroy`; versioning on; all public access blocked; ACLs disabled (`BucketOwnerEnforced`); SSE-S3, or SSE-KMS with a bucket key when `kms_key_arn` is set; a policy that denies non-TLS requests; noncurrent versions expire after `noncurrent_version_retention_days` (default 90) |
| `aws_dynamodb_table.lock` | Created when `create_lock_table` is true (the default). `LockID` string key, on-demand billing, deletion protection, point-in-time recovery, encrypted with `kms_key_arn` or the AWS managed key; `prevent_destroy` |

## Usage

```hcl
module "terraform_state" {
  source = "../../modules/aws/s3-terraform-state"

  bucket_name = "multiplayer-demo-tfstate-123456789012"
  tags = {
    Project = "multiplayer-demo"
  }
}
```

S3 bucket names are global across AWS, so include something unique, such as the account ID.

Then configure other configurations' backends with the outputs:

```hcl
terraform {
  backend "s3" {
    bucket         = "multiplayer-demo-tfstate-123456789012"
    key            = "aws/eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

On Terraform 1.10 or later, the backend can lock with the bucket alone by replacing `dynamodb_table` with `use_lockfile = true`; `dynamodb_table` is deprecated from 1.11. Once every configuration uses `use_lockfile`, set `create_lock_table = false`. That deletes the table, so first remove `prevent_destroy` from it in `main.tf`.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `bucket_name` | `string` | required | State bucket name: 3-63 lowercase letters, digits, dots, or hyphens. |
| `create_lock_table` | `bool` | `true` | Create the DynamoDB lock table. |
| `lock_table_name` | `string` | `"terraform-state-lock"` | Lock table name. |
| `kms_key_arn` | `string` | `null` | KMS key ARN for the bucket and table; null uses SSE-S3 and the AWS managed DynamoDB key. |
| `noncurrent_version_retention_days` | `number` | `90` | Days to keep overwritten or deleted state versions. |
| `tags` | `map(string)` | `{}` | Tags for the bucket and table. |

## Outputs

| Name | Description |
| --- | --- |
| `bucket_name` | Backend `bucket`. |
| `bucket_arn` | For IAM policies granting state access. |
| `bucket_region` | Backend `region`. |
| `lock_table_name` | Backend `dynamodb_table`; null without a lock table. |
| `lock_table_arn` | For IAM policies granting lock access; null without a lock table. |

## Destroying

`prevent_destroy` makes Terraform refuse any plan that deletes the bucket or table, and the table also has deletion protection. To retire them, move every state file out first, then remove both guards in a reviewed change. The bucket is not `force_destroy`, so it must also be emptied of all object versions before AWS will delete it.

## Tests

```bash
terraform -chdir=terraform/modules/aws/s3-terraform-state init -backend=false
terraform -chdir=terraform/modules/aws/s3-terraform-state test
```

The tests use a mocked AWS provider, so they need no credentials and create nothing. The `terraform-test` pre-commit hook runs them when files in this module change.
