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

  deletion_protection_enabled = true

  tags = {
    Name    = "${var.name_prefix}-dynamodb-items"
    Purpose = "DynamoDB table for items"
  }
}
