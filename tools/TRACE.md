# Tool selection trace (AZP-3)

Filled after a successful `dev` demo (`./agents/scripts/run-demo.sh` / Responses API).

**Agent:** `cloud-devops-standards-assistant:9` (`gpt-5-mini`)  
**Env:** `dev` — ASB Function `func-asb-csa-dev-8wlu`, Registry Function `func-reg-csa-dev-8wlu`, Search index `corpus-tuned`

## Non-Search tool (required)

**Question:** What is the current Azure Security Benchmark / MCSB version?

**Expected tool:** ASB version Azure Function (`get_asb_version`), not Azure AI Search.

**Observed:**

- Agent / version: `cloud-devops-standards-assistant:9`
- Tool steps seen: `openapi_call` / `openapi_call_output` (`asb_version_function_get_asb_version`) → `message`
- Answer summary (version/revision + source URL): **v2** / **2025-public** — https://learn.microsoft.com/security/benchmark/azure/introduction

## Registry tool

**Question:** What versions of the hashicorp/azurerm Terraform provider are listed on the public Registry?

**Expected tool:** `list_terraform_provider_versions` (Registry Function OpenAPI).

**Observed:**

- Tool steps seen: `openapi_call` / `openapi_call_output` (`terraform_registry_list_terraform_provider_versions`) → `message`
- Latest version reported (from tool output, not memory): **5.4.0** (`version_count` 405; sample `5.4.0` … `5.0.1`; source https://registry.terraform.io/v1/providers/hashicorp/azurerm/versions)

## Search still works

**Question:** What does WAF say about availability zones?

**Expected tool:** Azure AI Search.

**Observed:** Search call present with citations: **yes** — `azure_ai_search_call` / `azure_ai_search_call_output` → `message`  
Citations included Azure Well-Architected Framework / Reliability — Availability zones / *Use availability zones* (Learn + corpus blob URLs).

## Notes

- Registry OpenAPI targets slim `GET /terraform/azurerm/versions` on the **dedicated** Registry Function (live HashiCorp data). ASB stays on the ASB Function.
- CLI proves can be flaky on first turn (“I'll check…” without a tool call); retries with an explicit “call the tool” prompt and agent version pin succeeded.
- Failure-path check: see [FAILURE-HANDLING.md](FAILURE-HANDLING.md).
