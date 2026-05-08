locals {
  items_collection = { for k, v in var.lambda_functions : k => v if v.route_path == "items" }
  items_single     = { for k, v in var.lambda_functions : k => v if v.route_path == "items/{id}" }
}
