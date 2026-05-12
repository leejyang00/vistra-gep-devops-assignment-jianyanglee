variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "dynamodb_arn" {
  description = "ARN of the DynamoDB table the Lambda may access"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Lambda environment variable"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime identifier"
  type        = string
}

variable "lambda_memory_size" {
  description = "Lambda memory allocation in MB"
  type        = number
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_log_level" {
  description = "Log level for Lambda functions (LOG_LEVEL env var)"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "Retention period (in days) for CloudWatch log groups"
  type        = number
  default     = 30
}

variable "lambda_functions" {
  description = "Map of Lambda function configurations"
  type = map(object({
    handler     = string
    description = string
    http_method = string
    route_path  = string
  }))
}

variable "s3_bucket" {
  description = "S3 bucket name for deployment packages"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for IAM policy scoping"
  type        = string
}
