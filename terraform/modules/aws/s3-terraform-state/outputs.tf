output "bucket_name" {
  description = "State bucket name, for the backend's `bucket` argument."
  value       = aws_s3_bucket.state.id
}

output "bucket_arn" {
  description = "State bucket ARN, for IAM policies that grant state access."
  value       = aws_s3_bucket.state.arn
}

output "bucket_region" {
  description = "Region the state bucket is in, for the backend's `region` argument."
  value       = aws_s3_bucket.state.region
}

output "lock_table_name" {
  description = "DynamoDB lock table name, for the backend's `dynamodb_table` argument; null when create_lock_table is false."
  value       = one(aws_dynamodb_table.lock[*].name)
}

output "lock_table_arn" {
  description = "DynamoDB lock table ARN, for IAM policies that grant lock access; null when create_lock_table is false."
  value       = one(aws_dynamodb_table.lock[*].arn)
}
