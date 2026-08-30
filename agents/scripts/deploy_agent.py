#!/usr/bin/env python3
"""Create a Foundry Agent Service version (prompt agent + Azure AI Search tool)."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from azure.identity import DefaultAzureCredential

AGENTS_DIR = Path(__file__).resolve().parents[1]


def load_definition() -> dict:
    return json.loads((AGENTS_DIR / "standards-assistant.json").read_text(encoding="utf-8"))


def load_instructions() -> str:
    return (AGENTS_DIR / "instructions.md").read_text(encoding="utf-8").strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-endpoint", default=os.environ.get("FOUNDRY_PROJECT_ENDPOINT"))
    parser.add_argument("--connection-name", default=os.environ.get("SEARCH_CONNECTION_NAME", "csa-ai-search"))
    parser.add_argument("--index-name", default=os.environ.get("INDEX_NAME", "corpus-tuned"))
    parser.add_argument("--model", default=os.environ.get("CHAT_DEPLOYMENT"))
    args = parser.parse_args()

    if not args.project_endpoint:
        print("FOUNDRY_PROJECT_ENDPOINT / --project-endpoint is required", file=sys.stderr)
        return 1

    definition = load_definition()
    model = args.model or definition.get("model", "gpt-5-mini")
    display_name = definition["name"]
    agent_name = definition.get("agent_name") or "cloud-devops-standards-assistant"
    instructions = load_instructions()
    top_k = int(definition.get("grounding", {}).get("top_k", 5))
    query_type_name = definition.get("grounding", {}).get("query_type", "vector_simple_hybrid")

    from azure.ai.projects import AIProjectClient
    from azure.ai.projects.models import (
        AISearchIndexResource,
        AzureAISearchQueryType,
        AzureAISearchTool,
        AzureAISearchToolResource,
        PromptAgentDefinition,
    )

    query_map = {
        "simple": AzureAISearchQueryType.SIMPLE,
        "semantic": AzureAISearchQueryType.SEMANTIC,
        "vector": AzureAISearchQueryType.VECTOR,
        "hybrid": AzureAISearchQueryType.VECTOR_SIMPLE_HYBRID,
        "vector_simple_hybrid": AzureAISearchQueryType.VECTOR_SIMPLE_HYBRID,
        "vector_semantic_hybrid": AzureAISearchQueryType.VECTOR_SEMANTIC_HYBRID,
    }
    query_type = query_map.get(query_type_name, AzureAISearchQueryType.VECTOR_SIMPLE_HYBRID)

    credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
    client = AIProjectClient(endpoint=args.project_endpoint, credential=credential)

    connection = client.connections.get(args.connection_name)
    # Agent tool expects the connection *name*, not the ARM resource id.
    connection_id = connection.name
    print(f"Using Search connection: {connection_id}")

    tool = AzureAISearchTool(
        azure_ai_search=AzureAISearchToolResource(
            indexes=[
                AISearchIndexResource(
                    project_connection_id=connection_id,
                    index_name=args.index_name,
                    query_type=query_type,
                    top_k=top_k,
                )
            ]
        )
    )

    agent = client.agents.create_version(
        agent_name=agent_name,
        definition=PromptAgentDefinition(
            model=model,
            instructions=instructions,
            tools=[tool],
        ),
        description=definition.get("description") or display_name,
        metadata={"display_name": display_name},
    )

    out = {
        "id": agent.id,
        "name": agent.name,
        "version": getattr(agent, "version", None),
        "display_name": display_name,
        "model": model,
        "index_name": args.index_name,
        "connection_name": args.connection_name,
    }
    (AGENTS_DIR / ".last-deploy.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
