

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

# --- Lambda ---
output "lambda_function_names" {
  description = "List of Lambda function names"
  value       = module.lambda.lambda_function_names
}

output "lambda_function_arns" {
  description = "List of Lambda function ARNs"
  value       = module.lambda.lambda_function_arns
}

output "lambda_log_group_names" {
  description = "List of CloudWatch Log Group names for Lambda functions"
  value       = module.lambda.lambda_log_group_names
}