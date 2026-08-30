#!/usr/bin/env python3
"""Ask the deployed Foundry agent a question via Conversations + Responses."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from azure.identity import DefaultAzureCredential

AGENTS_DIR = Path(__file__).resolve().parents[1]


def resolve_agent_name(explicit: str | None, default: str) -> str:
    if explicit:
        return explicit
    last = AGENTS_DIR / ".last-deploy.json"
    if last.exists():
        data = json.loads(last.read_text(encoding="utf-8"))
        if data.get("name"):
            return data["name"]
    return default


def extract_tool_steps(response) -> list[dict]:
    steps = []
    for item in getattr(response, "output", None) or []:
        item_type = getattr(item, "type", None) or (item.get("type") if isinstance(item, dict) else None)
        entry = {"type": item_type}
        if item_type and "search" in str(item_type).lower():
            entry["detail"] = str(item)[:500]
        if hasattr(item, "model_dump"):
            dumped = item.model_dump()
            entry["type"] = dumped.get("type", item_type)
            if "call_id" in dumped:
                entry["call_id"] = dumped["call_id"]
            if "name" in dumped:
                entry["name"] = dumped["name"]
        steps.append(entry)
    return steps


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-endpoint", default=os.environ.get("FOUNDRY_PROJECT_ENDPOINT"))
    parser.add_argument("--agent-name", default=os.environ.get("AGENT_NAME"))
    parser.add_argument("--question", required=True)
    parser.add_argument("--out-json", default="")
    args = parser.parse_args()

    if not args.project_endpoint:
        print("FOUNDRY_PROJECT_ENDPOINT / --project-endpoint is required", file=sys.stderr)
        return 1

    from azure.ai.projects import AIProjectClient

    definition = json.loads((AGENTS_DIR / "standards-assistant.json").read_text(encoding="utf-8"))
    agent_name = resolve_agent_name(args.agent_name, definition.get("agent_name", "cloud-devops-standards-assistant"))

    credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
    project = AIProjectClient(endpoint=args.project_endpoint, credential=credential)

    with project.get_openai_client() as openai_client:
        conversation = openai_client.conversations.create(
            items=[{"type": "message", "role": "user", "content": args.question}],
        )
        response = openai_client.responses.create(
            conversation=conversation.id,
            extra_body={"agent_reference": {"name": agent_name, "type": "agent_reference"}},
        )

    answer = getattr(response, "output_text", None) or ""
    steps = extract_tool_steps(response)
    status = getattr(response, "status", "completed")

    payload = {
        "conversation_id": conversation.id,
        "response_id": getattr(response, "id", None),
        "status": status,
        "agent_name": agent_name,
        "question": args.question,
        "answer": answer,
        "steps": steps,
    }

    print(f"status={status}")
    print("--- answer ---")
    print(answer or "(empty)")
    print("--- output items ---")
    for step in steps:
        print(f"- {step.get('type')} {step.get('name', '')}".rstrip())

    if args.out_json:
        Path(args.out_json).write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
        print(f"Wrote {args.out_json}")
    return 0 if answer else 1


if __name__ == "__main__":
    raise SystemExit(main())
