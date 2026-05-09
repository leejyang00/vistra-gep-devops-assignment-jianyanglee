resource "aws_dynamodb_table" "items" {
  name         = "${var.name_prefix}-dynamodb-items"
  billing_mode = "PAY_PER_REQUEST" # On-Demand billing
  hash_key     = "id"

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "id"
    type = "S"
  }

  # attribute - status and createdAt can be added here later if needed for GSI --- IGNORE ---
  # GSI can be added here later once access patterns are known --- IGNORE ---

  deletion_protection_enabled = true

  tags = {
    Name    = "${var.name_prefix}-dynamodb-items"
    Purpose = "DynamoDB table for items"
  }
}
