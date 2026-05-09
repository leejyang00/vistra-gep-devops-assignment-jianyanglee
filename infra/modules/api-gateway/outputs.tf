output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_name" {
  description = "The name of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.name
}

output "api_endpoint" {
  description = "The endpoint URL of the API Gateway REST API"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_execution_arn" {
  description = "The ARN of the API Gateway REST API execution role"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "stage_name" {
  description = "The name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_log_group_name" {
  description = "CloudWatch Log Group name for API Gateway access logs"
  value       = aws_api_gateway_stage.main.access_log_settings[0].destination_arn
}