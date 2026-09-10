#!/usr/bin/env python3
"""Create a Foundry Agent Service version with Search + OpenAPI tools."""

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


def load_openapi_spec(
    rel: str,
    *,
    function_base_url: str,
    registry_function_base_url: str,
) -> dict:
    path = (AGENTS_DIR / rel).resolve()
    text = path.read_text(encoding="utf-8")
    text = text.replace("__FUNCTION_BASE_URL__", function_base_url.rstrip("/"))
    text = text.replace("__REGISTRY_FUNCTION_BASE_URL__", registry_function_base_url.rstrip("/"))
    return json.loads(text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-endpoint", default=os.environ.get("FOUNDRY_PROJECT_ENDPOINT"))
    parser.add_argument("--connection-name", default=os.environ.get("SEARCH_CONNECTION_NAME", "csa-ai-search"))
    parser.add_argument("--index-name", default=os.environ.get("INDEX_NAME", "corpus-tuned"))
    parser.add_argument("--model", default=os.environ.get("CHAT_DEPLOYMENT"))
    parser.add_argument("--function-base-url", default=os.environ.get("FUNCTION_BASE_URL", ""))
    parser.add_argument(
        "--registry-function-base-url",
        default=os.environ.get("REGISTRY_FUNCTION_BASE_URL", ""),
    )
    parser.add_argument(
        "--rai-policy-name",
        default=os.environ.get("RAI_POLICY_NAME", "csa-blocking-medium"),
        help="RAI policy short name or full ARM resource ID (empty to omit)",
    )
    parser.add_argument(
        "--rai-policy-id",
        default=os.environ.get("RAI_POLICY_ID", ""),
        help="Full ARM ID of the RAI policy (preferred for agent create)",
    )
    args = parser.parse_args()

    if not args.project_endpoint:
        print("FOUNDRY_PROJECT_ENDPOINT / --project-endpoint is required", file=sys.stderr)
        return 1
    if not args.function_base_url:
        print("FUNCTION_BASE_URL / --function-base-url is required for ASB Function OpenAPI", file=sys.stderr)
        return 1
    if not args.registry_function_base_url:
        print(
            "REGISTRY_FUNCTION_BASE_URL / --registry-function-base-url is required for Registry Function OpenAPI",
            file=sys.stderr,
        )
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
        OpenApiAnonymousAuthDetails,
        OpenApiFunctionDefinition,
        OpenApiTool,
        PromptAgentDefinition,
        RaiConfig,
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
    connection_id = connection.name
    print(f"Using Search connection: {connection_id}")

    search_tool = AzureAISearchTool(
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

    tools = [search_tool]
    tool_cfg = definition.get("tools") or {}
    for key, cfg in tool_cfg.items():
        spec = load_openapi_spec(
            cfg["spec"],
            function_base_url=args.function_base_url,
            registry_function_base_url=args.registry_function_base_url,
        )
        tools.append(
            OpenApiTool(
                openapi=OpenApiFunctionDefinition(
                    name=cfg.get("name") or key,
                    description=cfg.get("description"),
                    spec=spec,
                    auth=OpenApiAnonymousAuthDetails(),
                )
            )
        )
        print(f"Attached OpenAPI tool: {cfg.get('name') or key}")

    definition_kwargs: dict = {
        "model": model,
        "instructions": instructions,
        "tools": tools,
    }
    rai_ref = (args.rai_policy_id or args.rai_policy_name or "").strip()
    rai_short = args.rai_policy_name.strip() if args.rai_policy_name else None
    if rai_ref:
        definition_kwargs["rai_config"] = RaiConfig(rai_policy_name=rai_ref)
        print(f"RAI policy: {rai_short or rai_ref}")

    agent = client.agents.create_version(
        agent_name=agent_name,
        definition=PromptAgentDefinition(**definition_kwargs),
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
        "function_base_url": args.function_base_url.rstrip("/"),
        "registry_function_base_url": args.registry_function_base_url.rstrip("/"),
        "tool_count": len(tools),
        "rai_policy_name": rai_short or (None if not rai_ref else "custom"),
    }
    (AGENTS_DIR / ".last-deploy.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
