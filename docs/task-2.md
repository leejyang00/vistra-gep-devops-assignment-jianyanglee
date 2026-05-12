# Lambda Function Handlers

Node.js 22 ES Module handlers for the items REST API.

## Handler Summary

| File | Endpoint | Description |
|------|----------|-------------|
| `create-item.mjs` | `POST /items` | Validates input, generates UUID, returns 201 |
| `list-items.mjs` | `GET /items` | Paginated listing with `limit` and `nextToken` params |
| `get-item.mjs` | `GET /items/{id}` | Retrieves single item by path parameter |
| `update-item.mjs` | `PUT /items/{id}` | Partial update — only provided fields are modified |
| `delete-item.mjs` | `DELETE /items/{id}` | Conditional delete with 404 if item missing |

## Shared Utilities (`utils/`)

- **`dynamodb.mjs`** — Singleton `DynamoDBDocumentClient` using SDK v3 modular imports. Initialised once per Lambda container for connection reuse.
- **`logger.mjs`** — Structured JSON logger producing CloudWatch Insights-compatible log lines. Log level controlled via `LOG_LEVEL` environment variable.
- **`response.mjs`** — HTTP response builder with CORS headers. Standardises success/error response shapes across all handlers.
- **`validator.mjs`** — Input validation for item request bodies. Checks field types, lengths, and allowed values.

## Request Flow

```text
Client ──HTTPS──▶ API Gateway (REST, proxy integration, CORS)
                       │
                       ▼
                  Lambda handler  ──┐
                  (per route)       │  AWS SDK v3, lib-dynamodb doc client
                       │            │  (singleton, reused across warm invocations)
                       ▼            │
                  DynamoDB ◀────────┘
                  (conditional writes: attribute_not_exists / attribute_exists)
```

## Response & Error Contract

All responses share one envelope, built in [utils/response.mjs](../src/handlers/utils/response.mjs):

```json
// success
{ "success": true, "data": { ... } }
// error
{ "success": false, "error": { "message": "...", "details": [ ... ] } }
```

| Code | When | Helper |
|---|---|---|
| 201 | Created | `created(data)` |
| 200 | OK | `success(data)` |
| 400 | Malformed JSON or validation failure (`details` carries error array) | `badRequest(msg, details)` |
| 404 | Item not found (conditional-check failures in update/delete) | `notFound()` |
| 500 | Unhandled exception — logged with stack, message redacted to client | `serverError()` |

CORS headers are attached uniformly so no handler can forget them.

## Input Validation

Hand-rolled in [utils/validator.mjs](../src/handlers/utils/validator.mjs) — deliberately no `zod`/`ajv` dependency, keeping the cold-start path dependency-free. Each handler aggregates `validateRequiredFields()` + `validateItemInput()` into a single 400 response so the client gets every problem at once, not one round-trip per field.

## Lambda Module Composition

All five CRUD functions are driven from a single map in [infra/locals.tf](../infra/locals.tf) (`lambda_functions`) and provisioned via `for_each` in [infra/modules/lambda/main.tf](../infra/modules/lambda/main.tf). This means:

- **One shared execution role**, with least-privilege at the policy level — DynamoDB actions scoped to `var.dynamodb_arn` + `/index/*`, S3 reads scoped to `packages/${name_prefix}/*`.
- **Per-function log groups** created explicitly (not the Lambda-auto-created ones) so retention and tags are managed by Terraform from day one. Lambda functions `depends_on` their log group to avoid the create-then-rename race.
- **`source_code_hash`** wired from `data.archive_file.output_base64sha256` so a function only redeploys when its bytes change — mirrors the CI zip hash described in [task-3.md](task-3.md).

## API Gateway Design

A reusable `route/` sub-module ([infra/modules/api-gateway/modules/route/](../infra/modules/api-gateway/modules/route/)) encapsulates resource + method + integration + `aws_lambda_permission`, so adding a new route is one module block. Proxy integration (`AWS_PROXY`) is used throughout — the event shape stays standard and validation lives in the handler. The stage `aws_api_gateway_deployment.triggers` hashes the route configuration, so the deployment recreates automatically when routes change.

## Logging & Correlation

Every handler reads `event.requestContext.requestId` and threads it through every log line as `requestId`. Logs are JSON via [utils/logger.mjs](../src/handlers/utils/logger.mjs):

```json
{ "level": "info", "msg": "Item created", "requestId": "abc-123", "itemId": "..." }
```

This is what the CloudWatch Insights queries in [task-4.md](task-4.md) parse against.

## Environment Contract

Injected by Terraform, consumed by handlers via `process.env`:

| Variable | Source | Used for |
|---|---|---|
| `TABLE_NAME` | `module.dynamodb.table_name` | DynamoDB target table |
| `ENVIRONMENT` | `var.environment` | Tags log lines for environment filtering |
| `LOG_LEVEL` | `var.lambda_log_level` (default `info`) | Logger threshold |

## Trade-offs & Assumptions

- **Single-table, `id` as PK, no GSI.** List operations use `Scan` — fine at assignment scale, would become a GSI on `status` + `createdAt` in production.
- **`PAY_PER_REQUEST` billing.** Handlers don't need to reason about provisioned capacity; throttling is alarmed in [task-4.md](task-4.md).
- **Pagination via opaque `nextToken`** in `list-items` — base64-encoded `LastEvaluatedKey` so clients can't depend on the internal shape.
- **No local-invoke harness.** `terraform validate` + `node --check` + Biome are the local proxies; see [task-3.md](task-3.md).