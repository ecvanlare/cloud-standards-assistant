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
│   └── ARCHITECTURE.md
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

See [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md) and [`terraform/README.md`](terraform/README.md).

## Agent flow

Documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#agent-flow): retrieve via Azure AI Search (`corpus-tuned`), synthesise multi-source answers with citations, or defer when outside the corpus. Conversation state is Foundry conversations/responses. Deploy scripts live under [`agents/`](agents/).

## Evaluation

> To be documented once Phase 5 lands — the golden set, metrics (groundedness/relevance/safety), and results with failure analysis.

## Cost

> To be documented once Phase 6 lands — cost per interaction, and the effect of model tiering + prompt caching.

## Safety

> To be documented once Phase 6 lands — Content Safety configuration and what it catches (including a red-team log of prompt-injection attempts).

## Trade-offs and lessons learned

> To be filled in at the end of the build.

## License

MIT — see [LICENSE](LICENSE).
