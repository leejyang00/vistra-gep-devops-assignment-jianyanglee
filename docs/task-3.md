# CI/CD Strategy

## Approach

The pipeline is built around one principle: **fail fast on the cheapest signal first**. Lint and format checks run before validators; validators run before builds; builds run before security scans gate a merge. Every workflow is scoped by `paths:` so a docs-only change doesn't trigger Terraform, and a Terraform change doesn't rebuild Lambda zips. This keeps PR feedback under a couple of minutes for the common case while still giving full coverage on changes that warrant it.

All workflows are **deployment-free**. They prove the code is shippable without ever touching AWS — matching the assignment constraint and, more usefully, letting external contributors run the same checks locally via [scripts/](../scripts/) without credentials.

Hardening defaults applied uniformly: `permissions: contents: read` (least-privilege `GITHUB_TOKEN`), pinned action major versions, path-scoped triggers, and `concurrency` groups on the build workflow so superseded PR pushes get cancelled instead of queued.

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

Each workflow lives in [.github/workflows/](../.github/workflows/) and is summarised below.

### 1. Terraform validation — [terraform-validate.yaml](../.github/workflows/terraform-validate.yaml)

Runs the three checks the assignment calls out, in the order that produces the most useful failure message:

1. **`terraform fmt -check -recursive -diff`** — `continue-on-error: true` so a formatting nit doesn't mask a real validation error; the workflow re-fails at the end if `fmt` failed. This is a small but important UX detail: reviewers see *both* problems on one run, not two.
2. **`terraform init -backend=false`** — initializes providers and modules without needing remote state, so the workflow runs on any fork without secrets.
3. **`terraform validate`** — full HCL + provider schema validation.

Provider plugins are cached on `.terraform.lock.hcl` to keep cold runs honest and warm runs fast. A markdown summary is posted to `$GITHUB_STEP_SUMMARY` so reviewers can see pass/fail at a glance from the PR Checks tab without opening the log.

### 2. Security scan — [security-scan.yaml](../.github/workflows/security-scan.yaml)

Checkov scans `infra/` on every PR touching Terraform. Currently set to `soft_fail: true` — findings are surfaced in the run summary but don't block merges. The deliberate trade-off: in a greenfield assignment without an established baseline, hard-failing on every Checkov finding produces noise and trains reviewers to ignore the check. In a real environment the next step is to **(a)** triage the current findings, **(b)** suppress accepted ones via `skip_check` with rationale (already used for `CKV_AWS_144`/`CKV_AWS_145` — cross-region replication and MFA-delete on the deployment-package bucket, both out of scope here), and **(c)** flip `soft_fail: false`.

### 3. Lambda build — [lambda-build.yaml](../.github/workflows/lambda-build.yaml)

Validates Node.js 22 handler code and produces deployment-ready zips, structured as four jobs:

- **`discover`** — enumerates `src/handlers/*.mjs` and runs a `git diff` against the PR base / previous commit to identify which handlers actually changed. A change to `utils/`, `package*.json`, or `biome.json` flips a `rebuild_all` flag because shared code affects every package. Cheap (no Node setup) and gives downstream jobs a stable input contract.
- **`lint`** — single `npm ci` + `biome check`. Biome runs formatting and linting in one pass.
- **`build`** — installs prod-only dependencies (`npm ci --omit=dev`), then loops over handlers in a single runner: validates that each file exports `handler`, runs `node --check` for syntax, and produces a **content-addressable zip** (`<handler>-<sha256>.zip`). Zips are made deterministic by normalising mtimes and sorting entries before zipping, so identical source produces identical bytes — the same property `data.archive_file` provides via `output_md5` in [infra/modules/lambda/archiving.tf](../infra/modules/lambda/archiving.tf).
- A combined artifact (`lambda-packages`) plus a `manifest.json` mapping handler → sha256 is uploaded once. The workflow exposes itself as `workflow_call` with `artifact-name` and `manifest` outputs so a future deploy pipeline can consume it without re-zipping.

This shape was chosen over the obvious `strategy.matrix` per-handler approach because for small handlers (~kB of JS) the per-runner overhead — checkout, `setup-node`, `npm ci` — dwarfs the actual packaging work, and matrix concurrency would scale linearly with handler count. The discover step still emits the full handler list, so flipping back to a matrix is one diff away if handlers ever grow into something heavier (esbuild bundles, native deps, per-function tests).

### 4. Documentation lint — [docs-lint.yaml](../.github/workflows/docs-lint.yaml)

`markdownlint-cli` enforces consistent Markdown style across all `*.md` files, plus a small Bash check that flags broken intra-repo links. Cheap insurance against rotting documentation as the repo grows.

## How the pipelines support code quality

| Concern | How it is enforced | Where |
|---|---|---|
| **HCL style** | `terraform fmt -check -recursive` | [terraform-validate.yaml](../.github/workflows/terraform-validate.yaml) |
| **HCL correctness** | `terraform validate` against real provider schemas | [terraform-validate.yaml](../.github/workflows/terraform-validate.yaml) |
| **Infra security baseline** | Checkov scan, summarised on every PR | [security-scan.yaml](../.github/workflows/security-scan.yaml) |
| **JS style + lint** | Biome (formatter + linter in one pass) | [lambda-build.yaml](../.github/workflows/lambda-build.yaml) |
| **JS correctness** | `node --check` on every handler + shared util | [lambda-build.yaml](../.github/workflows/lambda-build.yaml) |
| **Packaging contract** | Each zip checked for `export const handler` and matching the structure consumed by [archiving.tf](../infra/modules/lambda/archiving.tf) | [lambda-build.yaml](../.github/workflows/lambda-build.yaml) |
| **Reproducible builds** | Deterministic zips with `sha256` in filename | [lambda-build.yaml](../.github/workflows/lambda-build.yaml) |
| **Docs hygiene** | `markdownlint` + internal-link check | [docs-lint.yaml](../.github/workflows/docs-lint.yaml) |
| **Local parity** | Same checks runnable via [scripts/](../scripts/) without GitHub | [terraform-fmt.sh](../scripts/terraform-fmt.sh), [terraform-validate.sh](../scripts/terraform-validate.sh), [node-validate.sh](../scripts/node-validate.sh) |
| **Supply-chain hygiene** | `permissions: contents: read`, path-scoped triggers, `concurrency` cancellation | All workflows |

## Trade-offs and next steps

- **Checkov `soft_fail`** stays on until the baseline is triaged; documented above.
- **No deploy job** — out of scope for the assignment. The natural next step is an OIDC-authenticated deploy workflow that consumes `lambda-build`'s `manifest` output and runs `terraform apply` against an environment-specific workspace, with the S3 hash check skipping unchanged uploads.
- **Action SHA pinning** — currently pinned to major versions for readability; production would pin to commit SHAs per CIS GitHub Actions hardening guidance, ideally automated via Dependabot.
- **Single source of truth for Lambda artifacts** — today CI zips for validation, and Terraform re-zips via `data.archive_file` for the actual deploy. A follow-up is to have Terraform read the CI-built S3 object directly (keyed by sha256), eliminating the "works in CI, different bytes in prod" risk.
