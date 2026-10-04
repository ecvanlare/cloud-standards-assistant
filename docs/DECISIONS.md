# Decisions

Each entry gives the choice, why it was made (with the source), what was rejected, and what it costs.

## Product

**Separate agent and judge models.** The agent runs on `gpt-5.4-mini` and the eval judge on `gpt-5-mini`.
- *Why:* Foundry Agent Service lists `gpt-5-mini` as unsupported for the Azure AI Search and OpenAPI tools ([tool support by model](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/limits-quotas-regions)). Keeping the judge fixed keeps scores comparable across agent versions.
- *Rejected:* instruction rewrites, forced `tool_choice` and higher reasoning effort. Each was tried and discarded ([`history.csv`](../eval/results/history.csv)).
- *Cost:* two chat deployments to hold quota for.

**Response completeness, not groundedness.**
- *Why:* response completeness scores the answer against the golden `ground_truth` ([built-in evaluators](https://learn.microsoft.com/en-us/azure/foundry/concepts/built-in-evaluators)). Groundedness and the tool-call evaluators have limited support for Azure AI Search calls ([agent evaluators](https://learn.microsoft.com/en-us/azure/foundry/concepts/evaluation-evaluators/agent-evaluators)).
- *Cost:* task adherence stays low (33.9%) because the judge can't see Search calls. It's reported but not gated.

**Route by question type.** Version questions go to a Function; only guidance questions use Search.
- *Why:* a version lookup needs no retrieval context, so it costs a short tool call instead of chunks plus synthesis ([evidence](EVIDENCE.md#cost-per-question)).

**Tuned chunking (800/150) over default (2000/500).**
- *Why:* section-sized passages give tighter citations on control-style documents. Both indexes cite the right WAF page ([evidence](EVIDENCE.md#chunking)).
- *Cost:* about 190 chunks instead of 79, so more embedding at index time.

**Terraform Registry through a Function.**
- *Why:* the Foundry OpenAPI tool did not reliably call `registry.terraform.io` directly. A small proxy returns only the fields the agent needs.

**Per-session conversations in memory.**
- *Why:* simple, and a session can never reach another session's conversation.
- *Cost:* after a scale-out a user may land on a new replica and start a fresh conversation. Redis or a signed cookie would fix that.

## Delivery

**Declarative first.** Terraform owns every Azure resource, including the Foundry connections and the RAI policy. Scripts handle only data-plane steps: Search definitions, corpus upload, agent versions and evals.
- *Why:* [Terraform for Foundry](https://learn.microsoft.com/en-us/azure/foundry/how-to/create-resource-terraform) and the [Azure AI Search tool](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/ai-search) both document project connections as resources. 24 shell scripts became 5.
- *Detail:* connections and the RAI policy use `azapi`. `azurerm_cognitive_account_rai_policy` requires a severity on every filter, including Jailbreak, which would drift from the live policy ([azurerm#28653](https://github.com/hashicorp/terraform-provider-azurerm/issues/28653)).

**GitHub OIDC to one managed identity per environment.**
- *Why:* there's no client secret to store or rotate. Federated credentials on a user-assigned identity are a documented option, and environment secrets are recommended for public repositories ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)).
- *Rejected:* `azd pipeline config`. Its Terraform support is in beta, and it creates a client secret for Terraform projects ([Learn](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/use-terraform-for-azd), [azure-dev#5264](https://github.com/Azure/azure-dev/issues/5264)).

**Constrained role assignment.** Deploy identities get Role Based Access Control Administrator with a condition that allows only the roles the stack assigns.
- *Why:* that's Microsoft's least-privilege alternative to Owner or User Access Administrator ([delegate with conditions](https://learn.microsoft.com/en-us/azure/role-based-access-control/delegate-role-assignments-overview)).

**Build once, promote the same image.** Dev builds `csa-serving:<commit>`; staging imports it from dev, and prod imports it from staging.
- *Why:* what was tested is what ships ([GenAIOps workflow](https://github.com/Azure/GenAIOps/blob/main/documentation/git_workflow.md)).

**Eval gate before promotion.** Each deploy runs 8 golden questions and fails if any pass rate falls below [`eval/thresholds.json`](../eval/thresholds.json) (one miss below the v17 screen).
- *Why:* WAF treats evaluation as the go/no-go check for AI changes ([test AI workloads](https://learn.microsoft.com/en-us/azure/well-architected/ai/test)).
- *Rejected:* `microsoft/ai-agent-evals`. It is in beta and reports results but has no threshold to fail a job.
- *Cost:* 8 rows is a smoke signal. The full 62-question run is a manual workflow.

**Microsoft deploy actions where they exist:** `azure/login` and `Azure/functions-action` (Flex Consumption remote build, [Learn](https://learn.microsoft.com/en-us/azure/azure-functions/functions-how-to-github-actions)).

## Known Well-Architected trade-offs

| Pillar | Trade-off | What would close it |
|---|---|---|
| Security | Foundry, Search and storage use public endpoints. Key auth is disabled on Foundry and Search. | Private endpoints and VNet integration |
| Security | Deploy identities hold Contributor at subscription scope, because Terraform creates the resource group. | Pre-created groups and resource-group scope |
| Security | Function host storage uses an account key. | Identity-based host storage |
| Reliability | Single region, no failover | Paired-region deployment |
| Reliability | The session map is per replica. | Shared session store |
| Cost | The budget alert is set by hand, not in code. | `azurerm_consumption_budget_subscription` |
| Operations | The corpus is fetched from live public pages at deploy time. | Versioned corpus snapshot |
