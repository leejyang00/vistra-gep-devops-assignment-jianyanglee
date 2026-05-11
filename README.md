# Vistra Serverless REST API

Infrastructure as Code for a serverless CRUD API on AWS, built with Terraform and Node.js 22.

## What This Project Does

Provisions a complete serverless REST API stack:

- **API Gateway** REST API with five CRUD endpoints for `/items`
- **Lambda** functions (Node.js 22, ES Modules) with structured JSON logging
- **DynamoDB** table with encryption at rest and point-in-time recovery
- **S3** bucket for versioned Lambda deployment packages
- **EventBridge** for domain events and scheduled background processing
- **CloudWatch** dashboards, alarms, and structured logging
- **GitHub Actions** for validation, security scanning, and documentation linting

No AWS credentials are required. All code validates locally using `terraform validate` and `terraform fmt`.


---

## Project Structure

```
├── .github/workflows/                # CI/CD pipelines
│   ├── terraform-validate.yaml       #   Terraform fmt + init + validate
│   ├── lambda-build.yaml             #   Node.js build, syntax check, packaging
│   ├── security-scan.yaml            #   Checkov infrastructure security scan
│   └── docs-lint.yaml                #   Markdown linting and link checks
│
├── infra/                            # Terraform root module
│   ├── main.tf                       #   Module composition (wires everything)
│   ├── variables.tf                  #   Root input variables with validation
│   ├── outputs.tf                    #   Key resource IDs and API endpoint
│   ├── versions.tf                   #   Provider and Terraform constraints
│   ├── locals.tf                     #   Naming conventions, function map, tags
│   ├── iam-roles.tf                  #   Lambda execution roles and policies
│   └── modules/
│       ├── api-gateway/              #   REST API, methods, CORS, deployment
│       │   ├── main.tf
│       │   ├── integrations.tf       #     Lambda proxy integrations
│       │   ├── locals.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   ├── versions.tf
│       │   └── modules/route/        #     Reusable route sub-module
│       ├── lambda/                   #   Functions, archiving, log groups
│       │   ├── main.tf
│       │   ├── archiving.tf          #     Source-to-zip packaging
│       │   ├── files/                #     Built Lambda .zip artifacts
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── versions.tf
│       ├── dynamodb/                 #   Items table, encryption, PITR
│       ├── storage/                  #   S3 bucket, versioning, lifecycle
│       └── monitoring/               #   Dashboard, alarms, SNS notifications
│           ├── main.tf
│           ├── dashboard.tf          #     CloudWatch dashboard
│           ├── api-gateway-alarms.tf
│           ├── lambda-alarms.tf
│           ├── dynamodb-alarms.tf
│           ├── locals.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── versions.tf
│
├── src/handlers/                     # Node.js 22 Lambda function source
│   ├── create-item.mjs               #   POST /items
│   ├── list-items.mjs                #   GET /items
│   ├── get-item.mjs                  #   GET /items/{id}
│   ├── update-item.mjs               #   PUT /items/{id}
│   ├── delete-item.mjs               #   DELETE /items/{id}
│   ├── package.json                  #   ES Module config, SDK v3 dependencies
│   ├── package-lock.json
│   ├── biome.json                    #   Biome lint/format config
│   ├── README.md
│   └── utils/
│       ├── dynamodb.mjs              #   DynamoDB document client singleton
│       ├── logger.mjs                #   Structured JSON logger
│       ├── response.mjs              #   HTTP response builder with CORS
│       └── validator.mjs             #   Input validation helpers
│
├── dist/handlers/                    # Packaged Lambda .zip artifacts (build output)
│
├── scripts/
│   ├── terraform-fmt.sh              #   Terraform formatting check
│   ├── terraform-validate.sh         #   Terraform init + validate
│   ├── node-validate.sh              #   Node.js syntax check
│   └── api-call.sh                   #   Smoke-test deployed API endpoints
│
├── .markdownlint.json
├── .gitignore
├── assignment.md                    # assignment description
└── README.md 
```

### Why This Structure

**Separation of infrastructure and application code.** `infra/` and `src/` are independent concerns with different change cadences. Terraform modules change when infrastructure evolves; Lambda handlers change when business logic evolves. Keeping them apart means CI/CD pipelines can scope their triggers (`paths:` filters) and developers can reason about changes in isolation.

**Modules by AWS service, not by feature.** Each module owns one logical AWS resource group (e.g., `api-gateway/` owns the REST API, methods, integrations, and deployment). This aligns with how AWS permissions, quotas, and documentation are organised, making it easy for engineers to find and modify infrastructure. The alternative — feature-based modules like `crud-api/` that bundle Lambda + API Gateway + DynamoDB — creates tight coupling and makes reuse harder.

**Shared utilities in `utils/`.** The logger, response builder, validator, and DynamoDB client are shared across all handlers. Duplicating them per-handler would create maintenance burden and inconsistency. The `utils/` directory is packaged into every Lambda deployment ZIP.

**Optional modules via feature flags.** Monitoring modules are gated behind `enable_monitoring` boolean variables. This keeps the core stack minimal while allowing progressive enhancement. The `count` meta-argument on the module block conditionally includes them.

## API Endpoints

| Method | Path | Description | Status Codes |
|--------|------|-------------|--------------|
| `POST` | `/items` | Create a new item | 201, 400, 500 |
| `GET` | `/items` | List items (paginated) | 200, 400, 500 |
| `GET` | `/items/{id}` | Get item by ID | 200, 400, 404, 500 |
| `PUT` | `/items/{id}` | Update item by ID | 200, 400, 404, 500 |
| `DELETE` | `/items/{id}` | Delete item by ID | 200, 400, 404, 500 |

All endpoints return JSON with CORS headers. Request bodies are validated; malformed JSON or missing required fields return 400 with detailed error messages.

