# Serving

The chat UI and backend (FastAPI) on Azure Container Apps. The agent stays on Foundry; this app holds per-session conversations and calls it with a managed identity.

| Path | Role |
|---|---|
| `app/main.py` | `/health`, `/api/session`, `/api/ask` (returns `trace_id`), static UI |
| `app/static/` | Chat UI |
| `Dockerfile` | Python 3.11, uvicorn on port 8000 |
| `scripts/load-concurrent.sh` | Concurrent `/health` load for the scale evidence |
| `evidence/` | Replica-count screenshot |

The deploy workflow builds the image once per commit and promotes it unchanged. Scale rule, sessions and telemetry: [Architecture](../docs/ARCHITECTURE.md#serving).
