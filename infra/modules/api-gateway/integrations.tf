## Methods + integrations -> /items
module "items_route" {
  source = "./modules/route"

  rest_api_id  = aws_api_gateway_rest_api.main.id
  resource_id  = aws_api_gateway_resource.items.id
  integrations = local.items_collection

  # CORS headers for OPTIONS method response
  cors_headers = local.cors_headers
}

## Methods + integrations -> /items/{id}
module "item_route" {
  source = "./modules/route"

  rest_api_id  = aws_api_gateway_rest_api.main.id
  resource_id  = aws_api_gateway_resource.item.id
  integrations = local.items_single

  request_parameters = {
    "method.request.path.id" = true
  }
  # CORS headers for OPTIONS method response
  cors_headers = local.cors_headers
}

