# -----------------------------------------------------------------------------
# Root Module — Vistra Serverless REST API
# Composes child modules for a serverless CRUD API on AWS.
# -----------------------------------------------------------------------------


# --- Task 1: Foundation Infrastructure ---
module "storage" {
    source = "./modules/storage"

    name_prefix = local.name_prefix
}