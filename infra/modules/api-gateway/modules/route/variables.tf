variable "rest_api_id" {
  description = "API Gateway REST API ID"
  type        = string
}

variable "resource_id" {
  description = "API Gateway resource ID this route attaches methods to"
  type        = string
}

variable "integrations" {
  description = "Map of Lambda integrations to expose as methods on the resource"
  type = map(object({
    http_method = string
    invoke_arn  = string
  }))
}

variable "request_parameters" {
  description = "Method request parameters (e.g. path parameters for {id})"
  type        = map(bool)
  default     = {}
}
