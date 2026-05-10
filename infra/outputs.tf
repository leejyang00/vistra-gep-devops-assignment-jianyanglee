
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

# --- API Gateway ---
output "api_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "api_execution_arn" {
  description = "API Gateway execution ARN"
  value       = module.api_gateway.api_execution_arn
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = module.api_gateway.stage_name
}

output "api_log_group_name" {
  description = "CloudWatch Log Group name for API Gateway access logs"
  value       = module.api_gateway.api_log_group_name
}

# --- Monitoring ---
output "sns_topic_arn" {
  description = "ARN of the SNS topic for monitoring alerts"
  value       = module.monitoring.sns_topic_arn
}

output "alarm_names" {
  description = "List of CloudWatch alarm names created for monitoring"
  value       = module.monitoring.alarm_names
}
