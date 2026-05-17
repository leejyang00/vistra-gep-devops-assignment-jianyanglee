# Interview Prep — Vistra GEP DevOps Assignment

Personal cheat-sheet for the post-assessment interview. Written so I can re-read this in 10 minutes before the call and re-anchor on the **why** behind every decision in the repo.

> Tactical advice for myself before answering:
>
> 1. **Restate the question** in one sentence before answering — buys thinking time and prevents misfires.
> 2. Lead with the **decision**, then the **reason**, then the **trade-off I accepted**. Three sentences max before pausing.
> 3. If I don't know, say "I didn't implement that — here's how I'd approach it" rather than guessing.
> 4. Always have a **"what I'd do differently in production"** ready. Interviewers love seeing self-critique.

---

## 30-second elevator pitch of the repo

> "It's a serverless CRUD REST API on AWS — API Gateway → 5 Lambda handlers (Node 22, ES Modules) → DynamoDB — provisioned with Terraform organised by AWS service rather than feature, plus an S3 bucket for deployment artefacts and a monitoring module for CloudWatch dashboards/alarms. CI runs four GitHub Actions workflows that validate Terraform, lint and package the Lambdas, scan with Checkov, and lint the docs — all without AWS credentials. Tasks 1–4 are implemented, Task 5 (EventBridge) is intentionally out of scope."

---

## 1. Project structure & rationale (Task 1 — 30% of marks)

### What the interviewer is testing

Whether I understand IaC organisation trade-offs, not whether the layout is "correct". There is no correct answer; what matters is that I can defend mine.

### Talking points

- **Top-level split: `infra/` vs `src/` vs `docs/` vs `scripts/` vs `.github/`.** Different change cadences, different reviewers. CI workflows can scope `paths:` filters cleanly, and a Lambda code change doesn't trigger a Terraform plan.
- **Modules organised by AWS service, not by feature** (`api-gateway/`, `lambda/`, `dynamodb/`, `storage/`, `monitoring/`). Aligns with how AWS permissions, quotas, docs and engineer mental models are structured. The alternative — feature modules like `crud-api/` bundling Lambda + APIGW + DDB — couples unrelated concerns and hurts reuse.
- **Root module composition** ([infra/main.tf](infra/main.tf)) is the single place where modules are wired. Inputs flow: `storage` & `dynamodb` → `lambda` → `api-gateway`; `monitoring` reads from all three.
- **Single `locals.tf`** at root holds `name_prefix`, `common_tags`, and the `lambda_functions` map — the **single source of truth** for the CRUD surface. Adding a 6th endpoint = one entry in that map, nothing else.
- **Sub-module nesting** only where it earns its keep — `api-gateway/modules/route/` exists because route+method+integration+permission is a unit that repeats per resource path.
- **Optional features behind feature flags.** `enable_monitoring` + `count = var.enable_monitoring ? 1 : 0` lets the core stack stand alone.

### Likely questions & how I'll answer

- **"Why service-based modules over feature-based?"** → Reuse, IAM scoping clarity, smaller blast radius on changes. A feature module forces every consumer to inherit the whole bundle. With service modules, a future "orders API" reuses `lambda/`, `api-gateway/`, `dynamodb/` without copy-paste.
- **"Why one root module rather than per-environment roots?"** → Simplicity for an assignment. Production: I'd add `infra/envs/{dev,staging,prod}/` each with its own backend + tfvars, calling the same modules. Or use Terragrunt / workspaces. The current variable validation already gates `environment` to those three values.
- **"Why no remote backend?"** → Assignment forbids deployment and AWS credentials. Production: S3 backend with DynamoDB lock table, one per environment, encryption + versioning on.
- **"How would this scale to 50 endpoints?"** → The `lambda_functions` map pattern stays. I'd split the map by domain (items_functions, orders_functions...) and group routes under separate API Gateway resources, possibly multiple REST APIs behind a custom domain.

### Weak spots to be honest about

- No remote backend → no team-safe state.
- `iam-roles.tf` at the root currently only contains the API Gateway → CloudWatch role. The Lambda exec role lives **inside** the lambda module ([infra/modules/lambda/main.tf](infra/modules/lambda/main.tf)) — slightly inconsistent. I'd normalise: either all IAM at root, or all IAM inside the consuming module.

---

## 2. Lambda + API Gateway (Task 2)

### Lambda design

- **Five handlers, one shared execution role.** They all need the same CloudWatch + DynamoDB + S3:GetObject permissions. Per-function roles would be ceremony with no security gain. The moment one handler needs different permissions (e.g. an admin-only `purge-items`), it gets its own role.
- **Per-function CloudWatch log groups created explicitly by Terraform** (not Lambda auto-created). Two reasons:
  1. Lambda's auto-created log groups have **no retention policy** → unbounded storage cost.
  2. Terraform-managed groups carry tags and `retention_in_days` from day one.
- **`depends_on = [aws_cloudwatch_log_group.lambda_log_group, ...]`** on the Lambda resource avoids the race where Lambda auto-creates a group before Terraform tries to.
- **`source_code_hash = data.archive_file.lambda[each.key].output_base64sha256`** so a function only redeploys when its bytes actually change.
- **`for_each` driven by `var.lambda_functions`** — adding an endpoint is one map entry.

### Lambda packaging ([infra/modules/lambda/archiving.tf](infra/modules/lambda/archiving.tf))

- One zip per handler, each containing its own `.mjs` plus the shared `utils/`. Smaller packages, the Lambda console only shows relevant code, and a util change rebuilds all five (correct — utils are shared).
- Package object key includes the **archive MD5**: `packages/${name_prefix}/<handler>-<md5>.zip`. Content-addressable storage → versioning + cache-friendliness. Mirrors the SHA256-named zips produced by the CI workflow.
- **Honest trade-off to flag:** today CI builds zips for validation and Terraform re-zips via `data.archive_file` for "deploy". Two builds, two hashes possible. Production fix: have CI publish to S3 by sha256 and have Terraform reference the S3 object — eliminates "works in CI, drifts in prod".

### API Gateway design

- **REST API (not HTTP API).** REST gives me native API Gateway access logs, request validation, full CORS control, and matches the assignment wording. HTTP API would be cheaper and lower-latency — production trade-off depending on whether I need WAF / request validators / API keys.
- **AWS_PROXY integration** — the standard event shape, validation lives in the handler. Avoids body-mapping templates.
- **Reusable `route/` sub-module** ([infra/modules/api-gateway/modules/route/](infra/modules/api-gateway/modules/route/)) bundles method + integration + CORS OPTIONS for one resource. Adding `/orders` is one module block.
- **CORS via MOCK OPTIONS** in the route sub-module — standard pattern. The sub-module emits the response headers; the Lambda handlers also emit CORS headers via [utils/response.mjs](src/handlers/utils/response.mjs) so cross-origin actual requests work.
- **Deployment trigger** ([infra/modules/api-gateway/main.tf](infra/modules/api-gateway/main.tf)) is `sha1(jsonencode(...))` over resource IDs and route hashes. When the API surface changes, the deployment is recreated. `lifecycle { create_before_destroy = true }` to avoid downtime.
- **Stage access logs** in JSON to a dedicated log group with 14-day retention (shorter than Lambda 30 — APIGW logs are higher volume and less useful long-term).
- **`aws_lambda_permission` for_each per function** — required so APIGW can invoke each Lambda; scoped to `${rest_api.execution_arn}/*/*`.

### IAM least privilege

[infra/modules/lambda/main.tf](infra/modules/lambda/main.tf):

- **Logs:** scoped to `arn:aws:logs:*:*:log-group:/aws/lambda/${var.name_prefix}-*:*` — only the project's own log groups, not all of CloudWatch.
- **DynamoDB:** scoped to `var.dynamodb_arn` + `${var.dynamodb_arn}/index/*` — table only, no tagging/admin actions.
- **S3:** scoped to `${var.s3_bucket_arn}/packages/${var.name_prefix}/*` — only this project's packages, not the whole bucket.
- Three separate `aws_iam_policy_document` data sources composed with `source_policy_documents`. Easy to read, easy to add a fourth (e.g. SQS).

### Handler implementation ([src/handlers/](src/handlers/))

- **ES Modules everywhere** (`.mjs`). `package.json` sets `"type": "module"` (assignment requirement).
- **AWS SDK v3 modular imports** — `@aws-sdk/client-dynamodb` + `@aws-sdk/lib-dynamodb`. Smaller bundle than v2, tree-shakeable, native promises.
- **Singleton DocumentClient** initialised once per container in [utils/dynamodb.mjs](src/handlers/utils/dynamodb.mjs) — reused across warm invocations (connection reuse, fewer cold-start costs).
- **Structured JSON logger** ([utils/logger.mjs](src/handlers/utils/logger.mjs)) — every line carries `requestId` (from `event.requestContext.requestId`) so I can correlate APIGW → Lambda → DynamoDB logs in CloudWatch Insights.
- **Hand-rolled validator** ([utils/validator.mjs](src/handlers/utils/validator.mjs)) — chose this over `zod`/`ajv` to keep cold-start dependency-free for an assignment-scale API. Aggregates errors so the client gets every problem in one 400.
- **Standard response envelope** in [utils/response.mjs](src/handlers/utils/response.mjs): `{ success, data }` or `{ success: false, error: { message, details } }`. CORS headers attached uniformly so handlers can't forget them.
- Handlers wrap their logic in try/catch → log with stack → return `serverError()` with the error message redacted. No internal details leak to clients.

### Likely questions

- **"Why hand-rolled validation, not Zod?"** → Zero dependencies on the cold-start path. For an assignment with three fields, the cost-benefit favours hand-rolled. Production with rich schemas: Zod or Ajv with compiled validators.
- **"Why a singleton DocumentClient?"** → Re-initialising on every invocation pays a TCP/TLS handshake cost. Lambda containers are reused; a module-level singleton is reused with them. Standard SDK v3 pattern.
- **"Why REST API not HTTP API?"** → Access logs, request validators, full CORS control, fits assignment wording. HTTP API for cost/latency in greenfield production.
- **"How do you handle cold starts?"** → Smallest viable package (per-function zips), SDK v3 modular imports, singleton clients, no heavy frameworks. Provisioned concurrency is the next lever if p99 cold-start matters.
- **"What about idempotency on POST?"** → Currently not implemented. Production: client supplies an `Idempotency-Key` header, Lambda writes it to a DDB key with TTL, and short-circuits duplicates. The `attribute_not_exists(id)` ConditionExpression already prevents accidental ID collisions.

### Weak spots to be honest about

- The assignment said "DO NOT need to implement actual CRUD code that makes changes to database" — but `create-item.mjs` actually does call `PutCommand`. That's fine (more thorough than required) but I should be ready to explain it's wired but never deployed.
- No request-level Lambda authorizer or Cognito — `authorization = "NONE"`. Documented in README assumptions.
- CORS is `*` everywhere. Documented; production would lock down.
- No throttling configured at the APIGW stage level — would add usage plans / API keys for production.
- Single-table, no GSI, list = `Scan`. Fine at assignment scale, would become a GSI on `(status, createdAt)` once real query patterns emerge.

---

## 3. CI/CD (Task 3)

### Pipeline shape & ordering

Four workflows, each path-scoped, each runnable locally via [scripts/](scripts/):

1. [terraform-validate.yaml](.github/workflows/terraform-validate.yaml) — `fmt -check -recursive -diff` → `init -backend=false` → `validate`.
2. [security-scan.yaml](.github/workflows/security-scan.yaml) — Checkov over `infra/`.
3. [lambda-build.yaml](.github/workflows/lambda-build.yaml) — discover → lint (Biome) → build per-handler zip with sha256 in filename → upload `lambda-packages` artifact + `manifest.json`.
4. [docs-lint.yaml](.github/workflows/docs-lint.yaml) — markdownlint + intra-repo link check.

### Talking points

- **"Fail fast on the cheapest signal first."** `fmt` runs with `continue-on-error` so format and validate errors surface in one run, not two — but the workflow re-fails at the end so PRs can't merge dirty.
- **Path-scoped triggers.** Docs PRs don't trigger Terraform; Terraform PRs don't rebuild Lambda zips. Faster CI, cheaper minutes, smaller blast radius.
- **`concurrency` cancellation on PR pushes** — old runs cancel themselves when a new commit lands.
- **`permissions: contents: read`** on every workflow — least privilege for the GITHUB_TOKEN.
- **Local parity** is non-negotiable. Every CI check has a script in [scripts/](scripts/) that runs the same command. Engineers can debug without pushing.
- **Provider plugin caching** keyed on `.terraform.lock.hcl` so `terraform init` is fast on cache hit.
- **Deterministic Lambda zips** (normalised mtimes, sorted entries) → same bytes give same SHA256. The CI sha matches `data.archive_file.output_md5` in Terraform — proves reproducibility.
- **Discover step in `lambda-build`** uses `git diff` against the PR base / previous commit. A change in `utils/`, `package*.json`, or `biome.json` flips a `rebuild_all` flag because shared code affects every handler.
- **Single `npm ci` + sequential build, not `strategy.matrix`.** For ~kB of JS, per-runner overhead (checkout, setup-node, npm ci) dwarfs the work. If handlers grow heavier, flipping back to a matrix is one diff.
- **`workflow_call` outputs** on lambda-build (`artifact-name`, `manifest`) so a future deploy job can consume it without re-zipping.

### Security scanning

- **Checkov in `soft_fail: true` mode currently.** Honest reason: hard-failing on a greenfield baseline trains reviewers to ignore the check. The path forward is documented: triage findings → suppress accepted ones with `skip_check` + rationale → flip `soft_fail: false`.
- Already documented suppressions: `CKV_AWS_144` (cross-region replication on the package bucket) and `CKV_AWS_145` (MFA-delete) — both out of scope for this assignment.

### Likely questions

- **"Why Checkov over tfsec?"** → tfsec was archived/merged into Trivy. Checkov has broader coverage (also IaC-scans CloudFormation, K8s, Helm) and active maintenance. Either is defensible.
- **"How would you add a deploy stage?"** → New workflow triggered on `main`, OIDC federation to AWS (no long-lived secrets), consume `lambda-build`'s `manifest` output, `terraform plan` → manual approval → `terraform apply`. Per-environment workflows with environment protection rules.
- **"Why not pin actions to commit SHAs?"** → Trade-off: readability now vs. supply-chain hardening. CIS guidance is full SHA pinning; production should add Dependabot to keep them current. Currently pinned to majors.
- **"How do you handle secrets?"** → None in this repo. Production: GitHub OIDC + AWS IAM role (no static keys), per-environment secrets in repo Environments with required reviewers.
- **"What's missing from the pipeline?"** → No SCA (npm audit / Snyk / Trivy fs scan) for Lambda dependencies; no SAST for the JS code (Biome is a linter, not a security scanner); no terraform `plan` on PR with cost/diff comments. All easy adds.

### Weak spots

- **Soft-fail Checkov** is the obvious one — flag it before they do.
- **No drift detection** (scheduled `terraform plan` on `main`).
- **No version pinning of the Terraform CLI** beyond `~> 1.6` — production would pin exact minor.

---

## 4. Monitoring (Task 4)

### Talking points

- **Symptom-based alarming.** Alarms fire on **user-visible failure modes** (errors, latency, throttles), not on resource-level signals (CPU, memory) that may not translate into customer pain. Keeps signal-to-noise high.
- **Three tiers covered**, matching the request path:
  1. **API Gateway** — front door. 5XX rate + p99 latency = customer-perceived health.
  2. **Lambda** — compute. Errors, p99 duration, throttles **per function** (`for_each` on the function map) so a regression in one handler isn't averaged out.
  3. **DynamoDB** — persistence. Throttled requests catch capacity issues *before* they cascade to API 5XXs.
- **Single SNS topic** as fan-out. Adding Slack / PagerDuty / extra emails is a one-line subscription change.
- **Alarms in three files split by service** ([api-gateway-alarms.tf](infra/modules/monitoring/api-gateway-alarms.tf), [lambda-alarms.tf](infra/modules/monitoring/lambda-alarms.tf), [dynamodb-alarms.tf](infra/modules/monitoring/dynamodb-alarms.tf)). **Thresholds centralised in [locals.tf](infra/modules/monitoring/locals.tf)** so tuning doesn't touch alarm resources.
- **`treat_missing_data = "notBreaching"`** so quiet periods don't page on-call.
- **`alarm_actions` AND `ok_actions`** on Lambda errors and API 5XX → recovery transition is also notified, closing the loop after an incident.
- **`enable_monitoring` flag** with `count` on the module → core stack stands alone.
- **Email subscription gated** on `notification_email` being non-empty → module degrades gracefully if no contact configured.
- **CloudWatch dashboard** for human triage before drilling into logs.
- **CloudWatch Insights queries** documented in [docs/task-4.md](docs/task-4.md) — queries depend on the structured JSON logger format, including `requestId` for correlation across tiers.

### Threshold rationale

| Metric | Threshold | Why |
| ------ | --------- | --- |
| Lambda errors (sum) | > 5 in 10 min | Low enough to catch emerging issues; 2-period evaluation prevents flapping. |
| Lambda p99 duration | > 5000 ms | Above typical cold-start + DDB round-trip (~500 ms). Sustained = systemic. |
| Lambda throttles | > 0 | Always actionable — concurrency limit too low. |
| APIGW 5XX | > 3 in 10 min | Distinguishes occasional retry-safe blips from incidents. |
| APIGW p99 latency | > 3000 ms | End-to-end user-perceived ceiling. |
| DDB ThrottledRequests | > 0 | Capacity is insufficient — fix before upstream cascade. |

### Likely questions

- **"Why p99 not p50?"** → p50 hides tail latency that affects real users. p99 is the standard SLO target for user-facing APIs.
- **"Why symptom-based, not resource-based?"** → Resource alarms (CPU, memory) page on-call when nothing customer-facing is broken. Symptom alarms only page when users feel pain. Google SRE chapter 6.
- **"What about anomaly detection?"** → CloudWatch supports anomaly-detection alarms. Trade-off: needs ~14 days of baseline, can be noisy on seasonal traffic. Static thresholds first, anomaly detection once we know the baseline.
- **"How do you tune these?"** → Initial thresholds are conservative starting points. Iterate based on noise/miss rate over 2–4 weeks. Centralising thresholds in `locals.tf` makes that trivial.
- **"What's missing?"** → SLO/error-budget alarms (burn-rate alarms over multiple windows), distributed tracing (X-Ray), cost alarms, Synthetics canaries.

---

## 5. Architectural decisions to defend

These are called out in [README.md](README.md#key-architectural-decisions) — make sure I can speak to each unprompted.

| Decision | Reason | Trade-off |
| -------- | ------ | --------- |
| Shared IAM role for all CRUD lambdas | Identical permissions = no security gain from per-function roles | If one handler later needs different perms, it must be split out |
| Pre-created CloudWatch log groups | Auto-created groups have no retention → unbounded cost; race-free | More Terraform resources to manage |
| `PAY_PER_REQUEST` DynamoDB | No capacity planning; greenfield with unknown traffic | Higher per-request cost; switch to provisioned once stable |
| REST API Gateway (not HTTP) | Native access logs, request validators, full CORS, fits assignment | Higher cost & latency than HTTP API |
| Per-function zips with shared `utils/` injected | Smaller packages, console clarity, granular redeploy | Util change rebuilds all five (correct) |
| Deterministic zips (mtime norm + sorted) | Reproducible builds → CI hash matches Terraform hash | Needs care with packaging tooling |
| Service-based Terraform modules | Reuse, IAM scoping clarity, blast radius | Feature-level cohesion is split across modules |
| `enable_monitoring` feature flag | Core stack stands alone; progressive enhancement | One more variable to manage |

---

## 6. Assumptions & trade-offs (open with these — they're called out in README)

- `authorization = "NONE"` — no auth, by design for the assignment. Production = Cognito / Lambda authorizer / API keys.
- Handlers don't actually persist (per assignment wording) — except `create-item.mjs` which has a real `PutCommand`. The IAM, table, client wiring is production-ready regardless.
- Single-region. No DDB global table, no S3 CRR. Suitable when no multi-region RTO/RPO requirement.
- Soft-fail Checkov until baseline triaged.
- CORS `*` for assignment scope.
- **Task 5 (EventBridge + DLQ + scheduled processor) intentionally not implemented.** The monitoring module is structured to absorb event-driven resources without refactoring.

---

## 7. Likely "gotcha" questions & prepared answers

- **"Why didn't you do Task 5?"** → Time-boxed the submission to Tasks 1–4 with high quality rather than spread thin. The repo is structured to drop Task 5 in (new `eventbridge/` module + scheduled handler in `src/handlers/`) without refactoring existing modules. I can sketch the architecture: EventBridge rule → target Lambda → DLQ (SQS) → DLQ alarm on `ApproximateNumberOfMessagesVisible > 0`.
- **"How would you deploy this for real?"** → Add a deploy workflow on `main`, OIDC to AWS, consume `lambda-build` artifact, `terraform plan` → required-reviewer approval → `apply`. Per-environment GitHub Environments with separate state backends.
- **"How do you handle Terraform state?"** → Currently local (no AWS account). Production: S3 backend per environment, DynamoDB lock table, state encryption, versioning, regular state backups. Bootstrap state via a separate "bootstrap" stack.
- **"What if two engineers change the lambda map at the same time?"** → State locking prevents concurrent applies. PR review catches logical conflicts. The map is keyed by name so order doesn't cause spurious diffs.
- **"How would you do blue/green for Lambda?"** → Lambda aliases + traffic shifting via CodeDeploy, or weighted routing via API Gateway stage variables. Currently single alias `$LATEST`-equivalent — fine for the assignment.
- **"What about cost?"** → Pay-per-request DDB, on-demand Lambda, REST APIGW (~$3.50/M calls). Most expensive line at low volume is APIGW. Could swap to HTTP API (~$1/M) if features allow. CloudWatch Logs retention capped at 30/14 days.
- **"How would you test the Terraform?"** → Currently `terraform validate` + `fmt -check`. Production: `terraform plan` against an isolated test account, plus `terratest` for end-to-end module tests, plus OPA / Conftest policies on the plan output.
- **"How would you test the Lambdas?"** → `node --check` covers syntax. Production: Vitest unit tests on handlers (mock the SDK), integration tests against a localstack DDB or a dev account, contract tests against the OpenAPI spec.
- **"What about secrets at runtime?"** → No secrets needed currently. Production: Lambda environment vars from SSM Parameter Store / Secrets Manager (not raw env), KMS-encrypted, fetched at cold-start with caching.
- **"What's the request flow on a cold start?"** → APIGW receives request → routes to Lambda → Lambda init: pulls package from S3 (cached after first warm), starts Node 22 runtime, evaluates module (singleton DDB client created), invokes handler → DDB call → response → APIGW transforms → client. Warm: skip the init.

---

## 8. Things I'd say I'd do differently with more time

A short, honest list — be ready to volunteer one if asked "what would you improve?". Picking these is better than them finding worse ones.

1. **Move Lambda IAM out of the lambda module** to root `iam-roles.tf` for consistency with the APIGW role.
2. **Single source of truth for Lambda artefacts** — have CI publish to S3 by sha and have Terraform reference the S3 object instead of re-zipping.
3. **Per-environment root modules** with separate state backends.
4. **Flip Checkov to hard-fail** after triaging the baseline.
5. **Add a `terraform plan` on PR** with diff/cost comments via Atlantis or GitHub's plan-output action.
6. **Pin actions to commit SHAs** with Dependabot keeping them current.
7. **Add SCA on Lambda dependencies** (npm audit + Snyk or Trivy).
8. **Add SLO burn-rate alarms** alongside the static thresholds for production-grade alerting.
9. **Implement Task 5** with a clean EventBridge module and DLQ pattern.
10. **Add OpenAPI spec** as the source of truth for routes, generated into the API Gateway body.

---

## 9. Quick-recall facts (the boring details I might forget)

- Runtime: **Node.js 22.x**, ES Modules.
- AWS SDK: **v3**, `@aws-sdk/lib-dynamodb` for DocumentClient.
- Terraform: **>= 1.6**.
- DynamoDB: **PAY_PER_REQUEST**, SSE on, PITR on, deletion protection on, hash key `id` (string), no GSI.
- S3: versioning on, public access blocked, 90-day lifecycle on noncurrent versions.
- CloudWatch retention: Lambda **30 days**, APIGW access logs **14 days**.
- API Gateway type: **REST**, regional endpoint, stage `dev-stage`, AWS_PROXY integrations.
- IAM: shared Lambda exec role; logs scoped to `/aws/lambda/${name_prefix}-*`; DDB to table + `index/*`; S3 to `packages/${name_prefix}/*`.
- Linter: **Biome** (format + lint in one pass).
- Security scanner: **Checkov**, `soft_fail: true`.
- Naming convention: `${project_name}-${environment}-...` via `local.name_prefix`.
- All resources tagged: `Project`, `Environment`, `ManagedBy = terraform`.

---

## 10. Final reminders

- **Sit on questions for one beat before answering** — interviewers prefer thoughtful pauses over confident-sounding wrong answers.
- **It's okay to disagree with the assignment.** "I implemented it this way, but if I were starting fresh I'd…" shows engineering maturity.
- **Avoid jargon I can't expand.** If I say "least privilege", be ready to point at the exact `aws_iam_policy_document` resources.
- **Have one specific number ready** (e.g. "DDB on-demand is ~$1.25 per million writes") — concrete numbers make me sound like I've operated this, not just designed it.
- **Close strong.** When asked "any questions for us?", ask about *their* IaC patterns — module organisation, state backend strategy, how they manage drift, how they roll out Terraform module changes across teams. Shows I'd be thinking like a teammate from day one.
