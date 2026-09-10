# Cloud & DevOps Standards Assistant

Answers cloud standards questions from a public corpus (WAF, Azure Security Benchmark / MCSB, NIST, Terraform docs), cites sources, and defers when outside knowledge. Built on Microsoft Foundry and Terraform in UK South.

## Azure stack

| Layer | What we use |
|---|---|
| Platform | Microsoft Foundry (`ais-csa-*` / `proj-csa-*`) |
| Model | `gpt-5-mini` + `text-embedding-3-small` |
| Retrieval | Azure AI Search (`corpus-tuned`, hybrid) |
| Agent | Foundry Agent Service |
| Tools | AI Search tool; Azure Functions (ASB version, Terraform Registry proxy) |
| App | Azure Container Apps (chat UI + BFF) |
| Secrets | Key Vault + user-assigned managed identity |
| Guardrails | Foundry RAI policy `csa-blocking-medium` + instruction guards |
| Observability | Foundry Traces / Control Plane → Application Insights; BFF OpenTelemetry |
| Evaluation | Golden set in repo + Foundry cloud Evaluations |
| IaC | Terraform (`dev` / `staging` / `prod`) |

## Architecture

```mermaid
flowchart LR
  User --> ACA[Container_App_UI_BFF]
  ACA --> Agent[Foundry_Agent_Service]
  Agent -->|retrieve| Search[Azure_AI_Search]
  Agent -->|ASB_version| FuncASB[Azure_Function]
  Agent -->|TF_versions| FuncReg[Registry_Function]
  Search --> Corpus[(WAF_ASB_NIST_TF)]
  Agent --> RAI[RAI_content_filters]
  ACA -->|OTel| AI[App_Insights]
  Agent -->|Control_Plane| AI
  Agent --> Answer[Answer_plus_citation]
```

Detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repository structure

```
cloud-standards-assistant/
├── terraform/     # modules + envs
├── search/        # index, skillsets, corpus scripts
├── agents/        # agent definition + deploy/demo
├── tools/         # Functions + OpenAPI contracts
├── safety/        # RAI policy + red-team notes
├── eval/          # golden_set.jsonl + runners
├── serving/       # Container Apps UI + BFF
├── scripts/       # dev-up / dev-down
└── docs/          # architecture, deploy, cost, observability
```

## Prerequisites

- Azure subscription with Microsoft Foundry access
- `az` CLI (logged in), Terraform >= 1.7
- Budget alert on the subscription
- `terraform/envs/dev/terraform.tfvars` from the example (subscription id — not committed)

## Quick start

One-time remote state:

```bash
az account set --subscription <subscription-id>
SUBSCRIPTION_ID=<subscription-id> ./terraform/bootstrap/bootstrap-state.sh
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init -backend-config=backend.hcl
```

Bring the stack up (infra + Functions + Search + agent + serving):

```bash
./scripts/dev-up.sh
# UI: terraform -chdir=terraform/envs/dev output -raw serving_url
```

Tear down when idle (AI Search Basic dominates cost):

```bash
CONFIRM_DESTROY=1 ./scripts/dev-down.sh
```

Step-by-step map: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md). Idle cost notes: [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md).

## Agent flow

1. **Retrieve** — hybrid Search on `corpus-tuned` for WAF / ASB / NIST / Terraform guidance; cite `framework` / `section` / `title`.
2. **ASB version** — Azure Function `get_asb_version` (live tool, not corpus).
3. **Terraform Registry** — dedicated Function proxies `registry.terraform.io` for provider/module versions.
4. **Multi-tool** — comparisons may call several tools in one turn.
5. **Defer** — pricing, live inventory, or no evidence: outside knowledge.

Deploy: [`agents/`](agents/), [`tools/`](tools/).

![Chat UI — live Registry tool + trace id](docs/screenshots/ui-ask-live-tool.png)

## Observability

- **UI / BFF:** each `/api/ask` returns a `trace_id`; the bubble shows tool path (e.g. `live-tool`) and a short trace prefix. BFF exports OpenTelemetry to Application Insights (`appi-csa-{env}`).
- **Foundry:** Control Plane **Traces** show duration, tokens in/out, and portal estimated cost per turn (same App Insights workspace when linked).

![Foundry Traces — tokens and estimated cost](docs/screenshots/foundry-traces.png)

How to join BFF and agent spans: [`docs/OBSERVABILITY.md`](docs/OBSERVABILITY.md).

## Evaluation

**Repo / CI:** [`eval/golden_set.jsonl`](eval/golden_set.jsonl) (≥50 rows). Metrics via Foundry evaluators / chat judge: groundedness, relevance, safety. Schema gate: `eval/scripts/validate-golden-set.py` (`.github/workflows/eval.yml`). Laptop runner: `eval/scripts/run_eval.py`.

**Foundry cloud:** golden rows upload into the project; runs appear under **Evaluation** (e.g. `csa-agent-cloud-eval`). Runbook: [`docs/FOUNDRY-EVAL.md`](docs/FOUNDRY-EVAL.md).

Baseline smoke (agent **v9**, run `smoke-20260910T070613Z`): overall **60%** (coherence / relevance 3/5). Honest baseline — strength is portal-visible cloud eval plus CI gates, with room to improve retrieval/synthesis.

![Foundry Evaluations list](docs/screenshots/foundry-evaluations-list.png)

![Cloud eval run summary](docs/screenshots/foundry-evaluation-run.png)

Local smoke notes: [`eval/FAILURE-ANALYSIS.md`](eval/FAILURE-ANALYSIS.md).

## Cost

| Path | When | Relative cost |
|------|------|----------------|
| Function / Registry only | ASB version, azurerm versions | Lower — short tool JSON + short completion |
| Search + synthesis | Standards guidance, comparisons | Higher — retrieved chunks in context |

Instructions route version questions to live tools and guidance to Search ([`docs/COST-PER-INTERACTION.md`](docs/COST-PER-INTERACTION.md)). Do not invent list prices; use Cost Analysis or [Azure pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/). Foundry Traces show per-turn estimated £ when App Insights is linked.

Idle: Search Basic is the largest fixed cost — `CONFIRM_DESTROY=1 ./scripts/dev-down.sh` when not demoing.

## Safety

Foundry RAI policy **`csa-blocking-medium`** (Prompt + Completion Blocking at Medium, Jailbreak) on `gpt-5-mini`, referenced from the agent `rai_config`. Instructions enforce cite-or-defer, XPIA resistance, and PII refusal. Red-team table (including a jailbreak blocked by `content_filter`): [`safety/RED-TEAM.md`](safety/RED-TEAM.md).

## Trade-offs and lessons learned

- **Registry via Function, not direct OpenAPI** — Foundry did not reliably call `registry.terraform.io`; a thin Azure Function proxy kept a dedicated URL and deploy unit.
- **Search SKU dominates idle spend** — tear down `dev` between demos; serving already scales toward zero.
- **Tool-path routing cuts waste** — version asks should not pay for hybrid retrieval.
- **In-memory sessions on ACA** — fine for a single-replica demo; scale-out can start a new Foundry conversation without leaking another user’s id ([`serving/ISOLATION.md`](serving/ISOLATION.md)).
- **BFF and Foundry traces may not share one W3C parent** — use `trace_id` + `conversation_id` to join.
- **RAI on the agent needs the policy ARM id** — a short name alone is rejected by Agent Service.
- **Cloud eval at 60% is a baseline** — portal visibility and CI matter more for the portfolio than a polished vanity score on day one.

## Demo video

Add a short recording (multi-step ask, e.g. compare two standards or ASB version + citation) and link it here when ready.

## License

MIT — see [LICENSE](LICENSE).
