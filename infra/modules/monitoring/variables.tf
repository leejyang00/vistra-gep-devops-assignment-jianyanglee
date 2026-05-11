variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "notification_email" {
  description = "Email address to receive alarm notifications (leave empty to disable)"
  type        = string
  default     = ""
}

variable "lambda_functions" {
  description = "Map of Lambda function names to monitor (key = logical name, value = actual function name)"
  type        = map(string)
}

variable "api_gateway_name" {
  description = "Name of the API Gateway to monitor"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to monitor"
  type        = string
}