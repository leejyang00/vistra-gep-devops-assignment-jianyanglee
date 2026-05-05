variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "dynamodb_arn" {
  description = "ARN of the DynamoDB table the Lambda may access"
  type        = string
}
