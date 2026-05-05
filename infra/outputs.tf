

# --- Storage ---
output "deployment_bucket" {
  description = "S3 bucket name for Lambda deployment packages"
  value       = module.storage.bucket_id
}

# --- Database ---
output "dynamodb_table_name" {
  description = "DynamoDB table name for application data"
  value       = module.dynamo_db.table_name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = module.dynamo_db.table_arn
}