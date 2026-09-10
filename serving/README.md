# Serving / Deployment

Thin **FastAPI BFF + chatbot UI** on Azure Container Apps. The agent stays on Foundry Agent Service; this app creates per-session conversations and calls the agent with the env user-assigned managed identity.

## Layout

| Path | Role |
|---|---|
| `app/main.py` | FastAPI: `/health`, `/api/session`, `/api/ask`, static UI |
| `app/static/` | Single-page chatbot (owned CSS/JS — no third-party template) |
| `Dockerfile` | Python 3.11 + uvicorn on port 8000 |
| `scripts/deploy-serving.sh` | ACR build → Terraform apply → smoke |
| `scripts/load-concurrent.sh` | Concurrent `/health` for scale evidence |
| `ISOLATION.md` | Per-session conversation rules + multi-replica note |
| `EVIDENCE.md` | Concurrent-load capture checklist |

## Deploy (dev)

Prereqs: `az login`, Terraform backend configured, Foundry agent already deployed.

```bash
./serving/scripts/deploy-serving.sh
```

First run creates ACR (`module.acr`), builds `csa-serving:latest`, then applies the Container App on existing `cae-csa-*`.

Outputs: `serving_url`, `acr_login_server`, `serving_container_app_name`.

## Scale

Terraform sets an HTTP scale rule (`concurrent_requests`, default 10) with `min_replicas` 0 and `max_replicas` 5. See `terraform/modules/container_app/`.

## Secrets

`SESSION_PEPPER` is a Key Vault secret referenced by the Container App (UAMI = Key Vault Secrets User). Foundry access uses the same UAMI (Cognitive Services User) — no API keys in source.

## Observability

The BFF exports OpenTelemetry to Application Insights via `APPLICATIONINSIGHTS_CONNECTION_STRING` (same `appi-csa-{env}` as Functions / Foundry Control Plane). `/api/ask` returns `trace_id` for the UI; spans carry `csa_session_id` and `csa_conversation_id` for joining when Foundry does not continue the W3C parent. See [`docs/OBSERVABILITY.md`](../docs/OBSERVABILITY.md).
