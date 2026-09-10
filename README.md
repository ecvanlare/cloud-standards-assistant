# Cloud & DevOps Standards Assistant

A production-grade GenAI platform on Azure, built with the native Microsoft Foundry stack and Terraform. It answers questions from a corpus of Azure Well-Architected Framework, Azure Security Benchmark, NIST, and Terraform best-practice documents, cites the exact source, and flags when a question falls outside its knowledge.

## Status

🚧 In progress. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the current design.

## The Azure GenAI Stack

| Layer | Service |
|---|---|
| Platform | Microsoft Foundry (formerly Azure AI Foundry) |
| Foundation models | Foundry model catalog |
| Retrieval / RAG | Azure AI Search (vector + hybrid), Foundry IQ |
| Agents | Foundry Agent Service |
| Tools | MCP tools (Foundry catalog), Azure Functions |
| Guardrails | Azure AI Content Safety, Foundry Control Plane safety |
| Observability | Foundry Control Plane (OpenTelemetry), Application Insights |
| Evaluation | Foundry evaluators (groundedness, relevance, safety) |
| Compute | Azure Container Apps |
| Secrets | Azure Key Vault |
| IaC | Terraform |

## Corpus

Public, non-confidential standards documents:

- Azure Well-Architected Framework
- Azure Security Benchmark
- NIST Cybersecurity Framework / relevant NIST 800-53 controls
- HashiCorp Terraform style guide / best-practice docs

## Repository structure

```
cloud-standards-assistant/
├── terraform/          # IaC: modules + dev/staging/prod envs
├── search/             # AI Search index definition + ingestion pipeline
├── agents/             # Foundry agent definitions
├── tools/              # Agent tool configs (AI Search, Azure Function, MCP/external API)
├── safety/             # Content Safety config, red-team notes
├── eval/
│   └── golden_set.jsonl
├── serving/            # Container Apps manifests
├── docs/
│   ├── INFRASTRUCTURE.md
│   ├── ARCHITECTURE.md
│   └── DEPLOYMENT.md
└── README.md
```


## Prerequisites

- Azure subscription with Microsoft Foundry access confirmed (this is the #1 first-time blocker — verify before anything else)
- Azure CLI (`az`), authenticated
- Terraform >= 1.7
- An Azure Storage account + container for Terraform remote state (bootstrap this first, see `terraform/README.md` once added)
- A budget alert configured on the subscription before any resources are deployed

## Quick start

Phase 1 (`dev`, UK South):

```bash
az account set --subscription <subscription-id>
SUBSCRIPTION_ID=<subscription-id> ./terraform/bootstrap/bootstrap-state.sh
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

See [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md) and [`terraform/README.md`](terraform/README.md). Local scripts vs pipeline jobs: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

## Agent flow

Documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#agent-flow): retrieve via Azure AI Search (`corpus-tuned`), call the ASB version Function or Terraform Registry when needed, synthesise with citations, or defer when outside knowledge. Conversation state is Foundry conversations/responses. Deploy scripts live under [`agents/`](agents/) and [`tools/`](tools/); scale map in [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).


## Evaluation

Golden set: [`eval/golden_set.jsonl`](eval/golden_set.jsonl) (≥50 questions; WAF / ASB / NIST / Terraform; ASB stands in for CIS). Schema and rules: [`eval/README.md`](eval/README.md).

Metrics (Foundry / `azure-ai-evaluation`): **groundedness**, **relevance**, **safety** (`ContentSafetyEvaluator`). Runner: `eval/scripts/run_eval.py`. Always-on schema gate: `eval/scripts/validate-golden-set.py` / CI workflow `.github/workflows/eval.yml`. Failure notes: [`eval/FAILURE-ANALYSIS.md`](eval/FAILURE-ANALYSIS.md).

## Cost

Idle infra notes remain in [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md). Per-request latency / tokens / cost views: [`docs/OBSERVABILITY.md`](docs/OBSERVABILITY.md) (Application Insights `appi-csa-{env}` + Foundry Control Plane tracing). Tool-path tiering and before/after notes: [`docs/COST-PER-INTERACTION.md`](docs/COST-PER-INTERACTION.md).

## Safety

Content Safety is Foundry **RAI content filters** (`csa-blocking-medium` on `gpt-5-mini`) plus instruction guards (citation, XPIA, PII). Config and red-team: [`safety/`](safety/) ([`content-safety.md`](safety/content-safety.md), [`RED-TEAM.md`](safety/RED-TEAM.md)). Apply with `./safety/scripts/apply-rai-policy.sh` then `./agents/scripts/deploy-agent.sh`.

## Trade-offs and lessons learned

> To be filled in at the end of the build.

## License

MIT — see [LICENSE](LICENSE).
