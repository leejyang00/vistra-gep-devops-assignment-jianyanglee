# --- Per-Function Deployment Packages ---
#
# Each Lambda gets its own ZIP containing only its handler file plus the
# shared lib/ utilities. This means:
#   - The Lambda console shows only relevant code for that function
#   - A change to create-item.mjs only redeploys the create-item Lambda
#   - Smaller packages (marginally faster cold starts at scale)
#
# The shared lib files are read once into a local and injected into each
# archive via dynamic source blocks. In a production CI/CD pipeline, a
# build script would replace this with per-function npm workspaces or
# esbuild bundles.

locals {
  handler_source_dir = "${path.module}/../../../src/handlers"

  # Shared lib files included in every function package
  shared_lib_files = {
    "utils/logger.mjs"    = file("${local.handler_source_dir}/utils/logger.mjs")
    "utils/response.mjs"  = file("${local.handler_source_dir}/utils/response.mjs")
    "utils/validator.mjs"  = file("${local.handler_source_dir}/utils/validator.mjs")
    "utils/dynamodb.mjs"   = file("${local.handler_source_dir}/utils/dynamodb.mjs")
  }
}

# --- Deployment Package ---
# Archive the source directory, upload to S3, and reference from Lambda.
data "archive_file" "lambda" {
  for_each = var.lambda_functions

  type        = "zip"
  output_path = "${path.module}/files/${replace(each.key, "_", "-")}.zip"

  # The handler file for this specific function
  source {
    content  = file("${local.handler_source_dir}/${replace(each.key, "_", "-")}.mjs")
    filename = "${replace(each.key, "_", "-")}.mjs"
  }

  # Shared lib/ utilities — injected into every package
  dynamic "source" {
    for_each = local.shared_lib_files
    content {
      content  = source.value
      filename = source.key
    }
  }
}

resource "aws_s3_object" "lambda_package" {
  for_each = var.lambda_functions

  bucket = var.s3_bucket
  key    = "packages/${var.name_prefix}/${replace(each.key, "_", "-")}-${data.archive_file.lambda[each.key].output_md5}.zip"
  source = data.archive_file.lambda[each.key].output_path
  etag   = data.archive_file.lambda[each.key].output_md5

  tags = {
    Name     = replace(each.key, "_", "-")
    Function = each.key
    Version  = data.archive_file.lambda[each.key].output_md5
  }
}