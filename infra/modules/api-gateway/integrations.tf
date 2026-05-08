# Methods + integrations for /items
module "items_route" {
  source = "./modules/route"

  rest_api_id  = aws_api_gateway_rest_api.main.id
  resource_id  = aws_api_gateway_resource.items.id
  integrations = local.items_collection
}

# Methods + integrations for /items/{id}
module "item_route" {
  source = "./modules/route"

  rest_api_id  = aws_api_gateway_rest_api.main.id
  resource_id  = aws_api_gateway_resource.item.id
  integrations = local.items_single

  request_parameters = {
    "method.request.path.id" = true
  }
}
