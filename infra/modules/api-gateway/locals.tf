locals {
  items_collection = { for k, v in var.lambda_functions : k => v if v.route_path == "items" }
  items_single     = { for k, v in var.lambda_functions : k => v if v.route_path == "items/{id}" }

  cors_headers = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
