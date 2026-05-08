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
      handler = "create-item.handler"
      description = "Create a new item in the items collection"
      http_method = "POST"
      route_path = "items"
    }
    get_item = {
      handler     = "get-item.handler"
      description = "Retrieve a single item by ID"
      http_method = "GET"
      route_path  = "items/{id}"
    }
    list_items = {
      handler     = "list-items.handler"
      description = "List all items in the collection"
      http_method = "GET"
      route_path  = "items"
    }
    update_item = {
      handler     = "update-item.handler"
      description = "Update an existing item by ID"
      http_method = "PUT"
      route_path  = "items/{id}"
    }
    # delete_item = {
    #   handler     = "delete-item.handler"
    #   description = "Delete an item by ID"
    #   http_method = "DELETE"
    #   route_path  = "items/{id}"
    # }
  }
}