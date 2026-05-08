output "execution_role_arn" {
  description = "IAM execution role ARN shared by all CRUD Lambda functions"
  value       = aws_iam_role.lambda_exec_role.arn
}

output "lambda_function_names" {
  description = "List of Lambda function names"
  value       = [for fn in aws_lambda_function.lambda_api_items : fn.function_name]
}

output "lambda_function_arns" {
  description = "List of Lambda function ARNs"
  value       = [for fn in aws_lambda_function.lambda_api_items : fn.arn]
}

output "lambda_log_group_names" {
  description = "List of CloudWatch Log Group names for Lambda functions"
  value       = [for lg in aws_cloudwatch_log_group.lambda_log_group : lg.name]
}

output "function_details" {
  description = "Combined function details for API Gateway integration"
  value = { for k, v in aws_lambda_function.lambda_api_items : k => {
    function_name = v.function_name
    arn           = v.arn
    invoke_arn    = v.invoke_arn
    http_method   = var.lambda_functions[k].http_method
    route_path    = var.lambda_functions[k].route_path
  } }
}