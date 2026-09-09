# Observability (AZP-8)

Foundry **Control Plane** observes agent runs (model calls, tool calls, decisions) using **OpenTelemetry**-shaped telemetry. **Application Insights** (`appi-csa-{env}`) is the store/query plane, workspace-based on the existing Log Analytics workspace (`log-csa-{env}`).

```text
Agent / Functions  --OTel-->  Foundry Control Plane  -->  Application Insights
```

## What Terraform creates

| Resource | Name pattern | Module |
|----------|--------------|--------|
| Application Insights | `appi-csa-{env}` | [`terraform/modules/monitoring`](../terraform/modules/monitoring) |
| Log Analytics (existing) | `log-csa-{env}` | `container_apps_env` |
| Function host setting | `APPLICATIONINSIGHTS_CONNECTION_STRING` | both `asb` / `reg` Function Apps |

Outputs (sensitive connection string): `application_insights_name`, `application_insights_connection_string`, `application_insights_app_id`.

## Wire Foundry project to Application Insights

Terraform provisions App Insights and Function telemetry. Attach the Foundry project in the portal (product UI for Control Plane tracing):

1. Open **Azure AI Foundry** → project `proj-csa-{env}`.
2. Open **Tracing** / **Application Insights** (label varies by portal revision).
3. Select resource `appi-csa-{env}` in the same resource group.
4. Save. Run an agent turn that calls Search and/or a Function.
5. In App Insights → **Transaction search** / **End-to-end transaction**, open the request and confirm child spans for model and tools.

CLI helper (when available in your CLI extension set):

```bash
# Confirm the resource exists
az monitor app-insights component show \
  --app "$(cd terraform/envs/dev && terraform output -raw application_insights_name)" \
  --resource-group "$(cd terraform/envs/dev && terraform output -raw resource_group_name)" \
  --query '{name:name,appId:appId,workspace:workspaceResourceId}' -o json
```

## Dashboards / queries

Saved Kusto samples: [`docs/observability/queries.kql`](queries.kql).

Use them in App Insights **Logs** for:

- Request / dependency latency
- Token usage custom metrics / gen_ai attributes when exported by Foundry
- Cost signals (token counts × published rates, or portal Cost Analysis scoped to the AI account)

## Screenshot deliverable

Capture a portal screenshot of a single request/trace that shows **latency and token/cost-related fields**, save as:

`docs/observability/trace-cost-per-request.png`

Caption it in [`docs/observability/README.md`](README.md) with the approximate time and agent version (no subscription IDs).
