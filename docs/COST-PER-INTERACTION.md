# Cost per interaction (AZP-1)

Goal: document **tool-path tiering** (simple Function lookup vs Search synthesis) and what we know about **prompt caching** for this stack. No second chat model.

## Setup

| Item | Value |
|------|--------|
| Model | `gpt-5-mini` (single chat deployment) |
| Agent | `cloud-devops-standards-assistant` v10+ |
| Simple path | ASB/MCSB version → `get_asb_version` Function |
| Heavy path | Standards guidance → Azure AI Search (`corpus-tuned`) + synthesis |
| Measurement | Tool steps in `run_demo.py` JSON; App Insights / Foundry tracing per [`OBSERVABILITY.md`](OBSERVABILITY.md) |

**Pricing:** do not invent Azure list prices in this repo. Convert observed tokens using [Azure OpenAI / Foundry pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/) for your region, or Cost Analysis on the AI account. Below uses **relative** cost (tool hops + answer shape), not \$ amounts.

## Before (untuned habit)

Historically many turns called **Search** even when a live Function answered the question (extra embedding/retrieval + longer context). Evidence of Search-backed turns: [`tools/TRACE.md`](../tools/TRACE.md).

## After (instruction tool-path routing)

Instructions now say: version questions → Function/Registry **only**; standards questions → Search.

### Sample A — simple (ASB version) — 2026-09-10

Question: *What is the current Azure Security Benchmark version?*

Observed steps (agent v10): `reasoning` → **`openapi_call` / `openapi_call_output`** → `message`.  
**No Search call.** Answer cited the Function/Learn URL with version `v2` / `2025-public`.

Relative cost: **low** (short tool JSON + short completion). This is the “small model / simple lookup” substitute for the checklist’s CIS-number example (here: **ASB version**).

### Sample B — heavy (WAF pillars)

Question: *What are the five pillars of the Azure Well-Architected Framework?*

Expected steps: `azure_ai_search_*` → cited `framework` / `section` / `title`. Relative cost: **higher** (retrieval chunks in context + longer synthesis).

Session note (2026-09-10): several Responses API turns completed with reasoning-only “I’ll look that up” and **no tool call** under both v9 and v11 — treat as platform flakiness for that day; use TRACE / playground when capturing a full Search cost sample. Routing rules in instructions remain the intended optimisation.

## Prompt caching

For **Foundry Agent Service + `gpt-5-mini`**, this portfolio does **not** configure a separate prompt-cache service. Azure OpenAI–style automatic prompt caching (when offered for a model/API) is **not relied on** for Agents in our scripts: we do not set cache headers or measure cache-hit tokens in `run_demo.py`.

**Optimisation that *is* in scope:** avoid Search on version lookups (Sample A) so input tokens stay small regardless of cache.

If Microsoft later exposes cache-hit metrics on agent traces, add them under [`OBSERVABILITY.md`](OBSERVABILITY.md) and refresh this table.

## How to refresh numbers

```bash
export FOUNDRY_PROJECT_ENDPOINT="$(cd terraform/envs/dev && terraform output -raw foundry_project_endpoint)"
python3 agents/scripts/run_demo.py --project-endpoint "$FOUNDRY_PROJECT_ENDPOINT" \
  --question "What is the current Azure Security Benchmark version?" --out-json /tmp/cost-asb.json
# Inspect steps for openapi_call vs azure_ai_search_*
# Optional: App Insights query from docs/observability/queries.kql for token metrics
```

## Summary

| Path | Tools | Relative cost | Status |
|------|-------|---------------|--------|
| ASB/Registry version | Function OpenAPI only | Lower | **Proven** after routing instructions |
| Standards / comparison | Search + synthesis | Higher | Intended; capture tokens when Search fires |
| Prompt cache | N/A for Agents here | — | Documented as unsupported / unused |
