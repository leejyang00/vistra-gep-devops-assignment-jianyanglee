# Data sources for dynamic ARN construction
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  lambda_functions = {
    create_item = {
      handler = "create_item.lambda_handler"
      description = "Create a new item in the items collection"
      http_method = "POST"
      route = "/items"
    }
  }
}