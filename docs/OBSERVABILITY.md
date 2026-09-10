# Observability (AZP-8 + serving)

Foundry **Control Plane** observes agent runs (model calls, tool calls, decisions) using **OpenTelemetry**-shaped telemetry. The serving **Container App BFF** also exports OpenTelemetry to the **same** Application Insights (`appi-csa-{env}`), workspace-based on Log Analytics (`log-csa-{env}`).

```text
Browser  -->  ACA BFF (/api/ask)  --OTel-->  Application Insights
                    |
                    v
              Foundry Agent  --Control Plane OTel-->  Application Insights
                    |
        +-----------+-----------+
        v                       v
   AI Search tool          Function tools
   (RAG / hybrid)     --host AI-->  Application Insights
```

## What is correlated today

| Hop | How you find it |
|-----|-----------------|
| UI → BFF request | App Insights `requests` for the Container App; UI shows short `trace_id` on the answer bubble |
| BFF → Foundry HTTP | `dependencies` under the same `operation_Id` / `trace_id` when HTTP client instrumentation is active |
| Agent model + tools (Search / Functions) | Foundry Control Plane traces in the same App Insights resource (after portal link) |
| Join BFF ↔ agent when parent context is not shared | Custom dims `csa_session_id`, `csa_conversation_id` on the BFF span + Foundry conversation id / time window |

**Honest limit:** Foundry Agent Service does not always continue the BFF’s W3C `traceparent` as one App Insights transaction. RAG/vector work usually appears as the agent’s **Azure AI Search tool** span inside the Foundry trace, not as a separate Search-service child of the ACA request. Use `trace_id` + `csa_conversation_id` together when stitching.

## What Terraform creates

| Resource | Name pattern | Module |
|----------|--------------|--------|
| Application Insights | `appi-csa-{env}` | [`terraform/modules/monitoring`](../terraform/modules/monitoring) |
| Log Analytics (existing) | `log-csa-{env}` | `container_apps_env` |
| Function host setting | `APPLICATIONINSIGHTS_CONNECTION_STRING` | both `asb` / `reg` Function Apps |
| Serving Container App | `APPLICATIONINSIGHTS_CONNECTION_STRING` secret → env | `container_app` |

Outputs (sensitive connection string): `application_insights_name`, `application_insights_connection_string`, `application_insights_app_id`.

## Wire Foundry project to Application Insights

Terraform provisions App Insights, Function telemetry, and the serving BFF connection string. Attach the Foundry project in the portal (Control Plane tracing):

1. Open **Azure AI Foundry** → project `proj-csa-{env}`.
2. Open **Tracing** / **Application Insights** (label varies by portal revision).
3. Select resource `appi-csa-{env}` in the same resource group.
4. Save. Run an agent turn from the chatbot UI (or `run-demo.sh`) that calls Search and/or a Function.
5. In App Insights → **Transaction search** / **End-to-end transaction**, open the BFF request by `trace_id` from the UI; open Foundry traces for the same window / conversation.

CLI helper:

```bash
az monitor app-insights component show \
  --app "$(cd terraform/envs/dev && terraform output -raw application_insights_name)" \
  --resource-group "$(cd terraform/envs/dev && terraform output -raw resource_group_name)" \
  --query '{name:name,appId:appId,workspace:workspaceResourceId}' -o json
```

## Dashboards / queries

Saved Kusto samples: [`docs/observability/queries.kql`](observability/queries.kql) (includes serving `csa_*` custom dimensions).

## Screenshot deliverable

Capture a portal screenshot of a single request/trace that shows **latency and token/cost-related fields**, save as:

`docs/observability/trace-cost-per-request.png`

Caption it in [`docs/observability/README.md`](observability/README.md) with the approximate time and agent version (no subscription IDs).
