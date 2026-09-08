# Agents (Foundry Agent Service)

Definition and scripts for the **Cloud & DevOps Standards Assistant** (AZP-7 + AZP-3 tools).

## Layout

| Path | Role |
|------|------|
| `standards-assistant.json` | Name, model (`gpt-5-mini`), Search + OpenAPI tool config |
| `instructions.md` | When to Search vs Function vs Registry vs defer |
| `scripts/ensure-search-connection.sh` | Foundry project connection → Azure AI Search (AAD) |
| `scripts/deploy-agent.sh` | Upsert connection + create agent version |
| `scripts/run-demo.sh` | Conversation + response demo |

Tool OpenAPI specs and Function source live under [`tools/`](../tools/).

Conversation state is Foundry **conversations** / **responses**. Deploy copies `instructions.md` into the agent version. Portal Playground uses the same agent.

## Prerequisites

- Phase 1 `dev` stack + Search ingest + both Function Apps applied (`terraform/envs/dev`)
- `./tools/scripts/deploy-function.sh` so `/api/asb/version` is live
- `./tools/scripts/deploy-registry-function.sh` so Registry proxy routes are live
- Azure CLI logged in; Python packages installed by deploy scripts

## Deploy (dev)

```bash
./tools/scripts/deploy-function.sh
./tools/scripts/deploy-registry-function.sh
./agents/scripts/deploy-agent.sh
```

## Demo

```bash
./agents/scripts/run-demo.sh "What is the current Azure Security Benchmark version?"
./agents/scripts/run-demo.sh "What versions does hashicorp/azurerm have on the Terraform Registry?"
./agents/scripts/run-demo.sh "What does WAF say about availability zones?"
```

Local scripts vs enterprise pipeline: [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md).
