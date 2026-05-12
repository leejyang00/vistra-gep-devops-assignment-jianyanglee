# Monitoring Strategy

## Approach

The monitoring strategy is **symptom-based**: alarms fire on user-visible failure modes (errors, latency, throttling) rather than on resource-level signals (CPU, memory) that may or may not translate into user pain. This keeps the on-call signal-to-noise ratio high — every page corresponds to something a customer can feel.

Coverage spans the three tiers the request traverses:

1. **API Gateway** — the front door. 5XX rate and end-to-end p99 latency tell us whether requests are succeeding from the client's perspective.
2. **Lambda** — the compute layer. Errors, p99 duration, and throttles are tracked **per function** via `for_each` on the function map, so a regression in one handler doesn't get averaged out across the fleet.
3. **DynamoDB** — the persistence layer. Throttled requests indicate insufficient table capacity before customers see 5XXs upstream.

## Architecture

```text
CloudWatch metrics → CloudWatch Alarms → SNS topic → Email subscription
                  ↘ CloudWatch Dashboard (human-facing overview)
```

The monitoring module ([infra/modules/monitoring/](../infra/modules/monitoring/)) provisions:

- One **SNS topic** (`${name_prefix}-alarms`) as the single notification fan-out point. Adding Slack, PagerDuty, or additional emails later is a one-line subscription change.
- **CloudWatch alarms** in three files split by service: [lambda-alarms.tf](../infra/modules/monitoring/lambda-alarms.tf), [api-gateway-alarms.tf](../infra/modules/monitoring/api-gateway-alarms.tf), [dynamodb-alarms.tf](../infra/modules/monitoring/dynamodb-alarms.tf). Thresholds are centralised in [locals.tf](../infra/modules/monitoring/locals.tf) so tuning doesn't require editing alarm resources.
- One **CloudWatch dashboard** ([dashboard.tf](../infra/modules/monitoring/dashboard.tf)) giving an at-a-glance view across all three tiers, used during incident triage before drilling into logs.
- **Email subscription** to the SNS topic, gated on `notification_email` being non-empty so the module degrades gracefully when no contact is configured.

Alarms use `treat_missing_data = "notBreaching"` so a quiet period (no traffic) does not page on-call. Lambda errors and API 5XX alarms set both `alarm_actions` and `ok_actions` on the SNS topic so the recovery transition is also notified — closing the loop after an incident.

## Lambda Logging

Lambda functions emit **structured JSON logs** via [src/handlers/utils/logger.mjs](../src/handlers/utils/logger.mjs), which lets CloudWatch Logs Insights parse fields directly without regex. Every request includes the API Gateway `requestId`, enabling end-to-end correlation across the API Gateway → Lambda → DynamoDB path. The Insights queries below rely on this structure.

## Metrics and Thresholds

| Metric | Threshold | Rationale |
| ------ | --------- | --------- |
| Lambda Errors (sum) | > 5 in 10 min | Low threshold catches emerging issues early. Two evaluation periods prevent alarm flapping from single transient errors. |
| Lambda Duration (p99) | > 5000 ms | Well above the typical cold-start + DynamoDB round-trip (~500 ms). Sustained p99 above 5s indicates a systemic issue. |
| Lambda Throttles | > 0 | Any throttling is actionable — it means the concurrent execution limit is too low. |
| API Gateway 5XX | > 3 in 10 min | Distinguishes from occasional 5XX (retry-safe) vs. sustained errors (incident). |
| API Gateway Latency (p99) | > 3000 ms | End-to-end latency including API Gateway overhead. |
| DynamoDB ThrottledRequests | > 0 | Indicates table capacity is insufficient. |

## CloudWatch Insights Queries

**Find slow Lambda invocations:**

```text
fields @timestamp, @duration, @requestId
| filter @duration > 3000
| sort @duration desc
| limit 20
```

**Error rate by function:**

```text
filter @message like /ERROR/
| stats count() as errorCount by @log
| sort errorCount desc
```

**API Gateway latency percentiles:**

```text
fields @timestamp, integrationLatency, status
| stats avg(integrationLatency) as avgLatency,
        pct(integrationLatency, 95) as p95,
        pct(integrationLatency, 99) as p99
  by bin(5m)
```

**DLQ investigation — find failed events:**

```text
fields @timestamp, @message
| filter @logStream like /event-processor/
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```
