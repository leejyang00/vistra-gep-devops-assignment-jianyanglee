variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
  default     = "vistra-serverless-api"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,28}[a-z0-9]$", var.project_name))
    error_message = "Project name must be 4-30 characters, lowercase alphanumeric and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "lambda_runtime" {
  description = "Node.js runtime version for Lambda functions"
  type        = string
  default     = "nodejs22.x"

  validation {
    condition     = can(regex("^nodejs[0-9]+\\.x$", var.lambda_runtime))
    error_message = "Lambda runtime must be a valid Node.js runtime (e.g., nodejs22.x)."
  }
}

variable "lambda_memory_size" {
  description = "Memory allocation for Lambda functions in MB"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 3008
    error_message = "Lambda memory must be between 128 MB and 3008 MB."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}
