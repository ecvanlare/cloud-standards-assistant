# Deployment

Local scripts prove the stack on a laptop. Enterprise delivery runs the same steps from a pipeline. This doc maps **each deploy-related file → what replaces it when you scale**.

## Deploy order (same either way)

```text
1. Terraform apply                  →  provisions Function shells, ACR, serving Container App (+ URLs)
2. deploy-function.sh               →  ASB Function code
3. deploy-registry-function.sh      →  Registry Function code
4. deploy-search.sh                 →  (if needed) keeps Search tool working
5. deploy-agent.sh                  →  registers tools on Foundry using outputs from (1)
6. deploy-serving.sh                →  ACR build/push + refresh serving app (if image not yet applied)
7. run-demo.sh / browser UI         →  proves tools + serving path
```

| Today (local) | Enterprise (pipeline) |
|---------------|------------------------|
| `terraform apply` | GitHub Actions + OIDC + `terraform apply` job |
| `deploy-function.sh` | CI job: build/zip-deploy ASB Function + smoke |
| `deploy-registry-function.sh` | CI job: build/zip-deploy Registry Function + smoke |
| `deploy-search.sh` | CI job: index/skillset deploy + indexer run |
| `deploy-agent.sh` | CI job: promote Foundry agent version per env |
| `deploy-serving.sh` | CI job: ACR build + Container App revision + smoke |
| `run-demo.sh` | Post-deploy eval / synthetic monitoring suite |
| `TRACE.md` (manual) | Observability dashboard + automated eval reports |

**Local (dev):**

```bash
./scripts/dev-up.sh
CONFIRM_DESTROY=1 ./scripts/dev-down.sh

# Step-by-step:
cd terraform/envs/dev && terraform apply
./tools/scripts/deploy-function.sh
./tools/scripts/deploy-registry-function.sh
./search/scripts/deploy-search.sh   # only if search/ or corpus changed
./agents/scripts/deploy-agent.sh
./serving/scripts/deploy-serving.sh
./agents/scripts/run-demo.sh "What is the current Azure Security Benchmark version?"
# Or open terraform output -raw serving_url in a browser
```

`dev-up.sh` runs Terraform, Functions, Search, agent, and serving. Flags: `SKIP_SEARCH=1`, `SKIP_AGENT=1`, `SKIP_SERVING=1`, `SKIP_RAI=0`.

**Enterprise:** the same order as jobs in one workflow (or separate workflows with `needs:`), with GitHub Environments (`dev` → `staging` → `prod`) and approval before prod.

## What stays the same

Enterprise mostly changes **who runs** the steps, not the product files:

- `tools/functions/asb_version/function_app.py` — tool implementation
- `tools/openapi/*.json` — contracts Foundry calls
- `agents/standards-assistant.json` + `agents/instructions.md` — agent config (versioned and gated)
- Terraform modules — infra source of truth

What gets replaced first: `_common.sh` output loading, `deploy-*.sh` wrappers, manual `TRACE.md`, and laptop `az login`.

## Scale ladder

| Stage | You run | Enterprise runs |
|-------|---------|-----------------|
| Local laptop | Shell commands | — |
| Team dev | PR merges; workflow deploys **dev** | `deploy-dev.yml` + OIDC |
| Staging | Tag or merge to staging | Workflow + approval + smoke eval |
| Prod | Rare manual promote | Workflow + change ticket + eval gate + rollback |

CI today: [`.github/workflows/terraform-ci.yml`](../.github/workflows/terraform-ci.yml) runs fmt/validate only. `terraform plan` stays commented until Azure OIDC is wired.

## File → enterprise replacement

### `tools/` — live tools (AZP-3)

| File | Today | Enterprise replacement |
|------|-------|------------------------|
| `tools/README.md` | Human runbook for tool layout and deploy order | Internal runbook / service catalog entry for the tools service |
| `tools/scripts/deploy-function.sh` | Zip-deploy Function via `az` + curl smoke | GitHub Actions job that builds, publishes artifact, deploys to slot, runs health check |
| `tools/functions/asb_version/function_app.py` | HTTP handler returning ASB version JSON | Same code, as a versioned container/zip artifact behind APIM + auth |
| `tools/functions/asb_version/host.json` | Functions runtime config | Same file, validated in CI; env overrides via App Settings / Terraform |
| `tools/functions/asb_version/requirements.txt` | Python deps for the Function | Locked dependency manifest in CI (SBOM scan) before publish |
| `tools/functions/asb_version/local.settings.json.example` | Local dev template (not secrets) | Developer local env only; prod uses App Configuration + Key Vault |
| `tools/openapi/asb-version-function.json` | OpenAPI contract; `__FUNCTION_BASE_URL__` filled at deploy | Published API spec in artifact registry; URL injected per env by pipeline / APIM |
| `tools/openapi/terraform-registry.json` | OpenAPI for public Registry endpoints | Curated gateway/MCP contract with egress allowlist and caching |
| `tools/FAILURE-HANDLING.md` | Retry/defer policy + demo query params | Ops runbook + automated alerts on tool error rate / latency |
| `tools/TRACE.md` | Manual evidence template for tool selection | Automated eval report + Foundry/App Insights trace per release |

### `agents/` — Foundry agent

| File | Today | Enterprise replacement |
|------|-------|------------------------|
| `agents/standards-assistant.json` | Agent name, model, Search grounding, OpenAPI tool refs | Versioned config manifest promoted staging → prod with change approval |
| `agents/instructions.md` | System prompt copied into agent at deploy | Versioned prompt registry with review and per-env promotion |
| `agents/scripts/_common.sh` | Loads Terraform outputs + `az` lookups into env vars | Pipeline step that reads Terraform outputs / App Configuration |
| `agents/scripts/ensure-search-connection.sh` | Ensures Foundry → Search connection exists | Terraform/Bicep owns the connection; deploy job only verifies |
| `agents/scripts/deploy-agent.sh` | Bash wrapper: pip install + call Python deploy | CI deploy job with pinned deps and OIDC auth |
| `agents/scripts/deploy_agent.py` | Creates Foundry agent version with Search + OpenAPI tools | Release promotion script; immutable agent version tagged to git SHA |
| `agents/scripts/run-demo.sh` | Ask the deployed agent one question | Post-deploy smoke / eval job (fixed questions, assert tool names) |
| `agents/scripts/run_demo.py` | SDK: conversation + response + print steps | Synthetic monitoring or `eval/` harness on schedule and after deploy |
| `agents/README.md` | How to deploy and demo the agent | Service catalog doc linked from pipeline and on-call runbooks |
| `agents/.last-deploy.json` (gitignored) | Last deploy metadata on your machine | Deployment record in CI artifacts (commit, agent version, env, time) |

### `terraform/modules/function_app/` — Function App infra

| File | Today | Enterprise replacement |
|------|-------|------------------------|
| `terraform/modules/function_app/main.tf` | Storage + FC1 Flex Consumption Function App (Python 3.11) | Same module, often Premium/Dedicated, VNet, private endpoints |
| `terraform/modules/function_app/variables.tf` | Module inputs | Same — fed by env tfvars or Terraform Cloud workspace variables |
| `terraform/modules/function_app/outputs.tf` | Name, hostname, `function_base_url`, MI principal | Same outputs consumed by pipeline as deployment targets |
| `terraform/envs/{dev,staging,prod}/main.tf` (function block) | Wires `function_app` per env | Same — apply only from approved pipeline per environment |
| `terraform/envs/{dev,staging,prod}/locals.tf` (function names) | Naming for Function/storage/plan | Same — naming enforced by policy-as-code |
| `terraform/envs/{dev,staging,prod}/outputs.tf` (function outputs) | Exposes URL/name to scripts | Pipeline reads after apply; optionally writes App Configuration |

### `search/scripts/` — corpus and index

| File | Today | Enterprise replacement |
|------|-------|------------------------|
| `search/scripts/_common.sh` | TF outputs + Search token helper | Shared pipeline library / composite action for Search auth |
| `search/scripts/fetch-corpus.sh` | Downloads public corpus sources | Scheduled ingestion job with checksum + provenance logging |
| `search/scripts/upload-corpus.sh` | Uploads blobs to storage | Data pipeline with immutable blob versioning |
| `search/scripts/deploy-search.sh` | Deploys index, skillset, indexer definitions | CI job on `search/**` changes; blue/green index swap |
| `search/scripts/run-indexers.sh` | Triggers indexer runs | Event-driven reindex + monitoring on failures |
| `search/scripts/query-example.sh` | Manual hybrid query demo | Retrieval regression tests in eval suite |
| `eval/scripts/validate-golden-set.py` | Schema / ≥50-row gate (CI) | Required status check on agent/eval PRs |
| `eval/scripts/run_eval.py` | Agent answers + Foundry evaluators | Nightly / pre-release eval job with thresholds |
| `eval/scripts/run-regression.sh` | Schema always; `RUN_LIVE_EVAL=1` and/or `RUN_FOUNDRY_CLOUD_EVAL=1` | Gates merge; optional laptop/portal eval |
| `eval/scripts/ensure-storage-connection.sh` | Foundry ↔ corpus storage (Entra) for Datasets/Eval | Terraform/Bicep owns connection; job verifies |
| `eval/scripts/export-foundry-dataset.py` | Golden → Foundry JSONL (`query` + metadata) | Pipeline step before dataset upload |
| `eval/scripts/upload-foundry-dataset.py` | `datasets.upload_file` into project | Artifact promotion of golden set versions |
| `eval/scripts/run-foundry-eval.py` / `.sh` | Cloud agent eval run (portal Evaluations tab) | Scheduled Foundry eval job; see [`FOUNDRY-EVAL.md`](FOUNDRY-EVAL.md) |
| `docs/FOUNDRY-EVAL.md` | Storage RBAC, dual-path eval, cost warning | Internal eval runbook |
| `docs/OBSERVABILITY.md` | App Insights + Control Plane wiring | Shared dashboards / alerts from workbook |

### `serving/` — Container Apps UI + BFF

| File | Today | Enterprise replacement |
|------|-------|------------------------|
| `serving/app/main.py` | FastAPI BFF → Foundry conversations | Same app; optional Redis session store |
| `serving/app/static/` | Owned chatbot UI | Design-system skin; same `/api/ask` contract |
| `serving/Dockerfile` | Image for ACR | Multi-stage CI build + signed digest |
| `serving/scripts/deploy-serving.sh` | ACR build + Terraform apply + smoke | Pipeline: build → push → revise Container App |
| `serving/scripts/load-concurrent.sh` | Concurrent `/health` for scale evidence | Load test job + Metrics alert |
| `serving/ISOLATION.md` | Per-session conversation note | Security design record |
| `terraform/modules/acr/` | Basic ACR + deployer AcrPush | Premium / geo / private link as needed |
| `terraform/modules/container_app/` | App + HTTP scale + KV secret ref | Same module; higher max replicas in prod |

### CI/CD and docs

| File | Today | Enterprise replacement |
|------|-------|------------------------|
| `.github/workflows/terraform-ci.yml` | PR: fmt + validate; plan commented out | Full CI/CD: plan on PR, apply on merge, OIDC, env gates |
| `.github/workflows/eval.yml` | Validates `golden_set.jsonl` (≥50) | Live evaluator job with OIDC + fail on score drop |
| `docs/ARCHITECTURE.md` | Architecture + app layer (ACA) | Living architecture (ADR/C4), synced from code where possible |
| `docs/INFRASTRUCTURE.md` | Infra inventory including Function App + App Insights | CMDB / infra diagram from Terraform state |
| Branch protection / repo policy | PR-only `main` (see `scripts/setup-branch-protection.sh`); no `terraform plan` in CI until OIDC | Required checks + OIDC before apply |

## Scripts and pipelines

Deploy scripts cover five surfaces (Terraform, Search, Functions, agent, serving). Pipelines should call the same entrypoints with OIDC; do not duplicate product contracts in workflow YAML.
