variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "lambda_functions" {
  description = "Map of Lambda function details from the lambda module"
  type = map(object({
    function_name = string
    arn           = string
    invoke_arn    = string
    http_method   = string
    route_path    = string
  }))
}