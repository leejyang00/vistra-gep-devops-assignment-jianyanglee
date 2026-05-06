variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "dynamodb_arn" {
  description = "ARN of the DynamoDB table the Lambda may access"
  type        = string
}

variable "lambda_functions" {
  description = "Map of Lambda function configurations"
  type = map(object({
    handler     = string
    description = string
    http_method = string
    route       = string
  }))
}

variable "runtime" {
  description = "Lambda runtime identifier"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name for deployment packages"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for IAM policy scoping"
  type        = string
}