"""Cloud Standards Assistant — ACA BFF to Foundry Agent Service."""

from __future__ import annotations

import os
import threading
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

STATIC_DIR = Path(__file__).resolve().parent / "static"

# session_id -> Foundry conversation_id (in-process only; see ISOLATION.md)
_sessions: dict[str, str] = {}
_lock = threading.Lock()

FOUNDRY_PROJECT_ENDPOINT = os.environ.get("FOUNDRY_PROJECT_ENDPOINT", "").rstrip("/")
AGENT_NAME = os.environ.get("AGENT_NAME", "cloud-devops-standards-assistant")
AGENT_VERSION = os.environ.get("AGENT_VERSION", "").strip() or None
MAX_OUTPUT_TOKENS = int(os.environ.get("MAX_OUTPUT_TOKENS", "4000"))
# Loaded from Key Vault secret ref on ACA (proves KV wiring; not a Foundry key).
SESSION_PEPPER = os.environ.get("SESSION_PEPPER", "")
MANAGED_IDENTITY_CLIENT_ID = os.environ.get("MANAGED_IDENTITY_CLIENT_ID", "").strip() or None
APPINSIGHTS_CONFIGURED = bool(os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "").strip())


def _configure_telemetry() -> None:
    """Configure Azure Monitor OTel. Safe to call once at import."""
    global APPINSIGHTS_CONFIGURED
    conn = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "").strip()
    APPINSIGHTS_CONFIGURED = bool(conn)
    if not conn:
        return
    from azure.monitor.opentelemetry import configure_azure_monitor

    configure_azure_monitor(connection_string=conn)


# Must run before FastAPI() so ASGI/HTTP instrumentation wraps the app.
_configure_telemetry()


def _trace_ids() -> tuple[str | None, str | None]:
    """Return (trace_id hex, span_id hex) for the active request span, if any."""
    try:
        from opentelemetry import trace

        span = trace.get_current_span()
        ctx = span.get_span_context() if span is not None else None
        if ctx is None or not ctx.is_valid:
            return None, None
        return format(ctx.trace_id, "032x"), format(ctx.span_id, "016x")
    except Exception:  # noqa: BLE001 — telemetry must not break asks
        return None, None


def _set_span_attrs(**attrs: Any) -> None:
    try:
        from opentelemetry import trace

        span = trace.get_current_span()
        if span is None or not span.is_recording():
            return
        for key, value in attrs.items():
            if value is not None and value != "":
                span.set_attribute(key, value)
    except Exception:  # noqa: BLE001
        return


def _credential():
    if MANAGED_IDENTITY_CLIENT_ID:
        return ManagedIdentityCredential(client_id=MANAGED_IDENTITY_CLIENT_ID)
    return DefaultAzureCredential(exclude_interactive_browser_credential=True)


def _extract_tool_steps(response: Any) -> list[dict]:
    steps: list[dict] = []
    for item in getattr(response, "output", None) or []:
        item_type = getattr(item, "type", None)
        entry: dict = {"type": item_type}
        if hasattr(item, "model_dump"):
            dumped = item.model_dump()
            entry["type"] = dumped.get("type", item_type)
            if dumped.get("name"):
                entry["name"] = dumped["name"]
        steps.append(entry)
    return steps


def _tool_path_hint(steps: list[dict]) -> str | None:
    names = " ".join(f"{s.get('type')}:{s.get('name')}" for s in steps)
    lower = names.lower()
    if "openapi" in lower or "asb" in lower or "registry" in lower:
        return "live-tool"
    if "search" in lower:
        return "search"
    return None


class AskRequest(BaseModel):
    question: str = Field(min_length=1, max_length=8000)
    session_id: str | None = Field(default=None, max_length=128)


class AskResponse(BaseModel):
    session_id: str
    conversation_id: str
    answer: str
    status: str
    tool_path: str | None = None
    pepper_configured: bool = False
    trace_id: str | None = None
    span_id: str | None = None


class SessionResponse(BaseModel):
    session_id: str


@asynccontextmanager
async def lifespan(_app: FastAPI):
    if not FOUNDRY_PROJECT_ENDPOINT:
        raise RuntimeError("FOUNDRY_PROJECT_ENDPOINT is required")
    yield


app = FastAPI(title="Cloud Standards Assistant", lifespan=lifespan)


@app.get("/health")
def health() -> dict:
    provider_name = "unknown"
    try:
        from opentelemetry import trace

        provider_name = type(trace.get_tracer_provider()).__name__
    except Exception:  # noqa: BLE001
        provider_name = "error"
    return {
        "status": "ok",
        "agent": AGENT_NAME,
        "pepper_configured": bool(SESSION_PEPPER),
        "appinsights_configured": APPINSIGHTS_CONFIGURED,
        "otel_provider": provider_name,
    }


@app.post("/api/session", response_model=SessionResponse)
def new_session() -> SessionResponse:
    session_id = str(uuid.uuid4())
    with _lock:
        _sessions.pop(session_id, None)
    return SessionResponse(session_id=session_id)


@app.post("/api/ask", response_model=AskResponse)
def ask(body: AskRequest) -> AskResponse:
    from azure.ai.projects import AIProjectClient
    from opentelemetry import trace

    question = body.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="question is required")

    tracer = trace.get_tracer("csa.serving")
    with tracer.start_as_current_span("csa.ask") as span:
        session_id = (body.session_id or "").strip() or str(uuid.uuid4())
        _set_span_attrs(
            csa_session_id=session_id,
            csa_agent_name=AGENT_NAME,
            gen_ai_system="foundry",
        )

        credential = _credential()
        project = AIProjectClient(endpoint=FOUNDRY_PROJECT_ENDPOINT, credential=credential)
        agent_ref: dict = {"name": AGENT_NAME, "type": "agent_reference"}
        if AGENT_VERSION:
            agent_ref["version"] = AGENT_VERSION

        try:
            with project.get_openai_client() as openai_client:
                with _lock:
                    conversation_id = _sessions.get(session_id)

                if conversation_id:
                    _set_span_attrs(csa_conversation_id=conversation_id, csa_turn="follow_up")
                    response = openai_client.responses.create(
                        conversation=conversation_id,
                        input=question,
                        extra_body={"agent_reference": agent_ref},
                        max_output_tokens=MAX_OUTPUT_TOKENS,
                    )
                else:
                    conversation = openai_client.conversations.create(
                        items=[{"type": "message", "role": "user", "content": question}],
                    )
                    conversation_id = conversation.id
                    with _lock:
                        _sessions[session_id] = conversation_id
                    _set_span_attrs(csa_conversation_id=conversation_id, csa_turn="new")
                    response = openai_client.responses.create(
                        conversation=conversation_id,
                        extra_body={"agent_reference": agent_ref},
                        max_output_tokens=MAX_OUTPUT_TOKENS,
                    )
        except Exception as exc:  # noqa: BLE001 — surface Foundry errors to client
            detail = str(exc)
            _set_span_attrs(csa_error=True, csa_error_preview=detail[:200])
            if "content_filter" in detail.lower() or "content management" in detail.lower():
                raise HTTPException(status_code=400, detail="Request blocked by content filter.") from exc
            raise HTTPException(status_code=502, detail=f"Foundry request failed: {detail[:500]}") from exc

        answer = getattr(response, "output_text", None) or ""
        steps = _extract_tool_steps(response)
        status = getattr(response, "status", "completed") or "completed"
        tool_path = _tool_path_hint(steps)
        trace_id, span_id = _trace_ids()
        _set_span_attrs(csa_tool_path=tool_path or "none", csa_response_status=status)

        # Prefer the explicit span we created (works even if ASGI auto-instrumentation is late).
        ctx = span.get_span_context()
        if ctx.is_valid:
            trace_id = format(ctx.trace_id, "032x")
            span_id = format(ctx.span_id, "016x")

        return AskResponse(
            session_id=session_id,
            conversation_id=conversation_id,
            answer=answer or "(empty response)",
            status=status,
            tool_path=tool_path,
            pepper_configured=bool(SESSION_PEPPER),
            trace_id=trace_id,
            span_id=span_id,
        )


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
