# -----------------------------------------------------------------------------
# Root Module — Vistra Serverless REST API
# Composes child modules for a serverless CRUD API on AWS.
# -----------------------------------------------------------------------------

# --- Task 1: Foundation Infrastructure ---
module "storage" {
  source = "./modules/storage"

  name_prefix = local.name_prefix
}

module "dynamo_db" {
  source = "./modules/dynamodb"

  name_prefix = local.name_prefix
}

# --- Task 1: Lambda Functions ---
module "lambda" {
  source = "./modules/lambda"

  name_prefix      = local.name_prefix
  dynamodb_arn     = module.dynamo_db.table_arn
  lambda_functions = local.lambda_functions
  runtime          = var.lambda_runtime
}
