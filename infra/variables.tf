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
