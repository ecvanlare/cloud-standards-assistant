# Serving

FastAPI BFF + chatbot UI on Azure Container Apps. The agent stays on Foundry; this app creates per-session conversations and calls it with the env managed identity.

## Layout

| Path | Role |
|---|---|
| `app/main.py` | `/health`, `/api/session`, `/api/ask`, static UI |
| `app/static/` | Chat UI |
| `Dockerfile` | Python 3.11, uvicorn `:8000` |
| `scripts/deploy-serving.sh` | ACR build → Terraform → smoke |
| `scripts/load-concurrent.sh` | Concurrent `/health` for scale proof |
| `ISOLATION.md` | Per-session conversations |
| `EVIDENCE.md` | Scale-out evidence |

## Deploy (dev)

```bash
./serving/scripts/deploy-serving.sh
```

Creates ACR if needed, builds `csa-serving:latest`, applies the Container App on `cae-csa-*`.

Outputs: `serving_url`, `acr_login_server`, `serving_container_app_name`.

## Scale and secrets

HTTP scale rule: `concurrent_requests` 10, `min_replicas` 0, `max_replicas` 5 (`terraform/modules/container_app/`).

`SESSION_PEPPER` from Key Vault (UAMI). Foundry via the same UAMI — no API keys in source.

## Observability

BFF → Application Insights (`APPLICATIONINSIGHTS_CONNECTION_STRING`). UI shows `trace_id`; spans include `csa_session_id` / `csa_conversation_id`. See [`docs/OBSERVABILITY.md`](../docs/OBSERVABILITY.md).
