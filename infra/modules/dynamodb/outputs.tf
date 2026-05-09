output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.items.name
}

output "table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.items.arn
}

output "table_id" {
  description = "DynamoDB table ID"
  value       = aws_dynamodb_table.items.id
}
