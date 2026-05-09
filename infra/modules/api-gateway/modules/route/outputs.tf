output "redeployment_hash" {
  value = sha1(jsonencode({
    methods                  = aws_api_gateway_method.this
    integrations             = aws_api_gateway_integration.this
    options_method           = aws_api_gateway_method.options
    options_integration      = aws_api_gateway_integration.options
    options_method_response  = aws_api_gateway_method_response.options
    options_integration_resp = aws_api_gateway_integration_response.options
  }))
}

