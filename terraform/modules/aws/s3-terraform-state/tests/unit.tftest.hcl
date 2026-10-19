# Unit tests with a mocked AWS provider: no credentials needed, no resources created.
# Run with `terraform -chdir=terraform/modules/aws/s3-terraform-state test`.

mock_provider "aws" {}

variables {
  bucket_name = "multiplayer-demo-tfstate-123456789012"
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "Bucket versioning should be enabled so earlier state can be restored."
  }

  assert {
    condition     = alltrue([aws_s3_bucket_public_access_block.state.block_public_acls, aws_s3_bucket_public_access_block.state.block_public_policy, aws_s3_bucket_public_access_block.state.ignore_public_acls, aws_s3_bucket_public_access_block.state.restrict_public_buckets])
    error_message = "All public access should be blocked."
  }

  # rule is a set, so it is read with a for expression instead of [0].
  assert {
    condition     = [for r in aws_s3_bucket_server_side_encryption_configuration.state.rule : r.apply_server_side_encryption_by_default[0].sse_algorithm] == ["AES256"]
    error_message = "Without kms_key_arn the bucket should use SSE-S3."
  }

  assert {
    condition     = length(aws_dynamodb_table.lock) == 1
    error_message = "The lock table should be created by default."
  }

  assert {
    condition     = aws_dynamodb_table.lock[0].hash_key == "LockID" && aws_dynamodb_table.lock[0].name == "terraform-state-lock"
    error_message = "The lock table should be named terraform-state-lock with the LockID key the S3 backend expects."
  }

  assert {
    condition     = aws_dynamodb_table.lock[0].billing_mode == "PAY_PER_REQUEST" && aws_dynamodb_table.lock[0].deletion_protection_enabled
    error_message = "The lock table should be on-demand and deletion-protected."
  }
}

run "kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = [for r in aws_s3_bucket_server_side_encryption_configuration.state.rule : r.apply_server_side_encryption_by_default[0].kms_master_key_id] == [var.kms_key_arn]
    error_message = "The bucket should be encrypted with the given KMS key."
  }

  assert {
    condition     = [for r in aws_s3_bucket_server_side_encryption_configuration.state.rule : r.bucket_key_enabled] == [true]
    error_message = "S3 bucket keys should be enabled with KMS to cut KMS request costs."
  }

  assert {
    condition     = aws_dynamodb_table.lock[0].server_side_encryption[0].kms_key_arn == var.kms_key_arn
    error_message = "The lock table should be encrypted with the given KMS key."
  }
}

run "s3_locking_only" {
  command = plan

  variables {
    create_lock_table = false
  }

  assert {
    condition     = length(aws_dynamodb_table.lock) == 0 && output.lock_table_name == null
    error_message = "create_lock_table = false should create no lock table."
  }
}

run "rejects_invalid_bucket_name" {
  command = plan

  variables {
    bucket_name = "Invalid_Bucket"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_invalid_kms_key_arn" {
  command = plan

  variables {
    kms_key_arn = "alias/terraform-state"
  }

  expect_failures = [var.kms_key_arn]
}
