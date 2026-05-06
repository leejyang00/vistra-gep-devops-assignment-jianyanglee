# -----------------------------------------------------------------------------
# Root Module — Vistra Serverless REST API
# Composes child modules for a serverless CRUD API on AWS.
# -----------------------------------------------------------------------------

# --- Task 1: Foundation Infrastructure ---
module "storage" {
  source      = "./modules/storage"
  name_prefix = local.name_prefix
}

module "dynamo_db" {
  source      = "./modules/dynamodb"
  name_prefix = local.name_prefix
}

# --- Task 2 Serverless API ---
module "lambda" {
  source      = "./modules/lambda"
  name_prefix = local.name_prefix
  environment = var.environment
  # dynamodb
  dynamodb_arn        = module.dynamo_db.table_arn
  dynamodb_table_name = module.dynamo_db.table_name
  # lambda
  lambda_functions   = local.lambda_functions
  lambda_runtime     = var.lambda_runtime
  lambda_memory_size = var.lambda_memory_size
  lambda_timeout     = var.lambda_timeout
  # s3 bucket
  s3_bucket     = module.storage.bucket_id
  s3_bucket_arn = module.storage.bucket_arn
}
