# Agents (Foundry Agent Service)

Definition and scripts for the **Cloud & DevOps Standards Assistant** (AZP-7).

## Layout

| Path | Role |
|------|------|
| `standards-assistant.json` | Name, model (`gpt-5-mini`), Search grounding config |
| `instructions.md` | Cite-or-defer instructions (retrieve / synthesise / defer) |
| `scripts/ensure-search-connection.sh` | Foundry project connection → Azure AI Search (AAD) |
| `scripts/deploy-agent.sh` | Upsert connection + create/update agent |
| `scripts/run-demo.sh` | Conversation + response; prints answer and tool-step summary |

Conversation state is managed by Foundry **conversations** and **responses** (no custom session store). Deploy copies `instructions.md` into the agent version; Foundry does not read the markdown file at runtime. You can also chat with the same agent in the Foundry portal Playground.

## Prerequisites

- Phase 1 `dev` stack + Phase 2 (`corpus-tuned` index ingested)
- Terraform identity: Foundry project (and account) MI has Search Index Data Contributor
- Azure CLI logged in; `terraform` outputs available under `terraform/envs/dev`
- Python 3 with packages installed by the deploy/demo scripts (`azure-ai-projects`, `openai`, `azure-identity`)

## Deploy (dev)

```bash
./agents/scripts/deploy-agent.sh
```

## Demo

```bash
./agents/scripts/run-demo.sh
# or
./agents/scripts/run-demo.sh "What does the Well-Architected Framework say about reliability zones?"
```

Default question is the ASB + WAF network-segmentation compare.

Phase 4 Function/MCP tools are out of scope here; retrieve = Azure AI Search tool; defer = instructions only. Hard Content Safety guardrails are a later phase.
