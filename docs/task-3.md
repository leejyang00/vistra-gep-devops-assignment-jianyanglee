# CI/CD Strategy

## Approach

**Fail fast on the cheapest signal first**, and keep every check **deployment-free** so it runs without AWS credentials. Workflows are scoped by `paths:` so a docs change doesn't trigger Terraform and a Terraform change doesn't rebuild Lambda zips. Hardening defaults applied uniformly: `permissions: contents: read`, pinned action majors, path-scoped triggers, and `concurrency` cancellation on PR pushes.

## Pipelines

```text
        ┌─ terraform-validate ─ fmt → init → validate
PR /    │
push ───┼─ security-scan ────── checkov (terraform)
        │
        ├─ lambda-build ──────── discover → lint (biome) → build & package
        │
        └─ docs-lint ────────── markdownlint + internal-link check
```

### 1. [terraform-validate.yaml](../.github/workflows/terraform-validate.yaml)

Runs the three assignment-required checks: `terraform fmt -check -recursive -diff` → `terraform init -backend=false` → `terraform validate`. `fmt` uses `continue-on-error: true` then re-fails at the end so reviewers see formatting _and_ validation issues on one run, not two. Provider plugins cached on `.terraform.lock.hcl`; results posted to `$GITHUB_STEP_SUMMARY`.

### 2. [security-scan.yaml](../.github/workflows/security-scan.yaml)

Checkov scans `infra/` on every Terraform-touching PR. `soft_fail: true` for now — hard-failing on a greenfield baseline trains reviewers to ignore the check. Path forward: triage findings, suppress accepted ones via `skip_check` with rationale (already done for `CKV_AWS_144`/`CKV_AWS_145` — cross-region replication and MFA-delete on the package bucket, both out of scope here), then flip to `soft_fail: false`.

### 3. [lambda-build.yaml](../.github/workflows/lambda-build.yaml)

Four jobs:

- **`discover`** — enumerates `src/handlers/*.mjs` and `git diff`s the PR base / previous commit. A change in `utils/`, `package*.json`, or `biome.json` flips a `rebuild_all` flag (shared code affects every package).
- **`lint`** — single `npm ci` + `biome check` (Biome runs format + lint in one pass).
- **`build`** — `npm ci --omit=dev`, then for each handler: assert `export const handler`, `node --check` syntax, and produce a **content-addressable** `<handler>-<sha256>.zip`. Zips are deterministic (normalised mtimes + sorted entries), giving the same `output_md5` property `data.archive_file` provides in [infra/modules/lambda/archiving.tf](../infra/modules/lambda/archiving.tf).
- A combined `lambda-packages` artifact + `manifest.json` (handler → sha256) is uploaded once. Workflow exposes itself as `workflow_call` with `artifact-name`/`manifest` outputs so a future deploy job can consume it without re-zipping.

Chosen over `strategy.matrix` per-handler: for ~kB of JS, per-runner overhead (checkout, `setup-node`, `npm ci`) dwarfs the work and matrix concurrency scales linearly with handler count. Discover still emits the full list — flipping back to a matrix is one diff away if handlers grow heavier.

### 4. [docs-lint.yaml](../.github/workflows/docs-lint.yaml)

`markdownlint-cli` across all `*.md` plus a Bash check for broken intra-repo links.

## How the pipelines support code quality

| Concern | Enforcement | Workflow |
| ------- | ----------- | -------- |
| HCL style + correctness | `terraform fmt -check`, `terraform validate` | [terraform-validate.yaml](../.github/workflows/terraform-validate.yaml) |
| Infra security baseline | Checkov, PR-summarised | [security-scan.yaml](../.github/workflows/security-scan.yaml) |
| JS style + lint | Biome (formatter + linter) | [lambda-build.yaml](../.github/workflows/lambda-build.yaml) |
| JS syntax + handler contract | `node --check`, `export const handler` assertion | [lambda-build.yaml](../.github/workflows/lambda-build.yaml) |
| Reproducible builds | Deterministic zips with `sha256` in filename | [lambda-build.yaml](../.github/workflows/lambda-build.yaml) |
| Docs hygiene | `markdownlint` + internal-link check | [docs-lint.yaml](../.github/workflows/docs-lint.yaml) |
| Local parity | Same checks via [scripts/](../scripts/) — no GitHub needed | [tf-fmt.sh](../scripts/tf-fmt.sh), [tf-validate.sh](../scripts/tf-validate.sh), [node-validate.sh](../scripts/node-validate.sh) |
| Supply-chain hygiene | `permissions: contents: read`, path-scoped triggers, `concurrency` cancellation | All workflows |

## Trade-offs and next steps

- **Checkov `soft_fail`** stays on until the baseline is triaged.
- **No deploy job** (out of scope). Natural next step: OIDC-authenticated workflow consuming `lambda-build`'s `manifest` output, skipping S3 uploads when the sha already exists.
- **Action SHA pinning** — currently major versions for readability; production would pin to commit SHAs per CIS GitHub Actions guidance, automated via Dependabot.
- **Single source of truth for Lambda artifacts** — today CI zips for validation, Terraform re-zips via `data.archive_file` for deploy. Follow-up: have Terraform read the CI-built S3 object by sha256, eliminating the "works in CI, different bytes in prod" risk.
