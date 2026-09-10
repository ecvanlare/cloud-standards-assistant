#!/usr/bin/env python3
"""Create and run a Foundry cloud Evaluation against the standards assistant agent.

Dataset upload uses AIProjectClient. Eval create / run / poll use the Foundry
OpenAI-compatible REST API via httpx so we avoid an openai SDK TypedDict bug
on Python 3.9 (NameError: Input is not defined during maybe_transform).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
from azure.identity import DefaultAzureCredential

ROOT = Path(__file__).resolve().parents[2]
AGENTS_DIR = ROOT / "agents"
EVAL_DIR = ROOT / "eval"
RESULTS_DIR = EVAL_DIR / "results"
DEFAULT_DATASET_FILE = RESULTS_DIR / "foundry-dataset.jsonl"
TOKEN_SCOPE = "https://ai.azure.com/.default"


def load_last_deploy() -> dict:
    path = AGENTS_DIR / ".last-deploy.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def openai_v1_base(project_endpoint: str) -> str:
    return project_endpoint.rstrip("/") + "/openai/v1"


def build_testing_criteria(model_deployment: str, *, with_safety: bool) -> list[dict]:
    criteria: list[dict] = [
        {
            "type": "azure_ai_evaluator",
            "name": "coherence",
            "evaluator_name": "builtin.coherence",
            "initialization_parameters": {"model": model_deployment},
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{sample.output_text}}",
            },
        },
        {
            "type": "azure_ai_evaluator",
            "name": "relevance",
            "evaluator_name": "builtin.relevance",
            "initialization_parameters": {"model": model_deployment},
            "data_mapping": {
                "query": "{{item.query}}",
                "response": "{{sample.output_text}}",
            },
        },
    ]
    if with_safety:
        criteria.append(
            {
                "type": "azure_ai_evaluator",
                "name": "violence",
                "evaluator_name": "builtin.violence",
                "initialization_parameters": {"model": model_deployment},
                "data_mapping": {
                    "query": "{{item.query}}",
                    "response": "{{sample.output_text}}",
                },
            }
        )
    return criteria


class FoundryEvalsRest:
    """Minimal REST client for /openai/v1/evals* (Entra bearer)."""

    def __init__(self, project_endpoint: str, credential: DefaultAzureCredential) -> None:
        self._base = openai_v1_base(project_endpoint)
        self._credential = credential
        self._client = httpx.Client(timeout=120.0)

    def close(self) -> None:
        self._client.close()

    def _headers(self) -> dict[str, str]:
        token = self._credential.get_token(TOKEN_SCOPE)
        return {
            "Authorization": f"Bearer {token.token}",
            "Content-Type": "application/json",
        }

    def _request(self, method: str, path: str, *, json_body: dict | None = None) -> dict[str, Any]:
        url = f"{self._base}{path}"
        response = self._client.request(method, url, headers=self._headers(), json=json_body)
        if response.status_code >= 400:
            raise RuntimeError(
                f"{method} {url} -> {response.status_code}: {response.text[:2000]}"
            )
        if not response.content:
            return {}
        return response.json()

    def create_eval(self, body: dict) -> dict[str, Any]:
        return self._request("POST", "/evals", json_body=body)

    def create_run(self, eval_id: str, body: dict) -> dict[str, Any]:
        return self._request("POST", f"/evals/{eval_id}/runs", json_body=body)

    def get_run(self, eval_id: str, run_id: str) -> dict[str, Any]:
        return self._request("GET", f"/evals/{eval_id}/runs/{run_id}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-endpoint", default=os.environ.get("FOUNDRY_PROJECT_ENDPOINT"))
    parser.add_argument(
        "--model",
        default=os.environ.get("CHAT_DEPLOYMENT") or os.environ.get("FOUNDRY_MODEL_NAME"),
        help="Judge chat deployment name",
    )
    parser.add_argument("--dataset-id", default=os.environ.get("FOUNDRY_DATASET_ID"))
    parser.add_argument("--dataset-file", type=Path, default=DEFAULT_DATASET_FILE)
    parser.add_argument("--dataset-name", default=os.environ.get("FOUNDRY_DATASET_NAME", "csa-golden-smoke"))
    parser.add_argument(
        "--dataset-version",
        default=os.environ.get("FOUNDRY_DATASET_VERSION")
        or datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S"),
    )
    parser.add_argument(
        "--connection-name",
        default=os.environ.get("STORAGE_CONNECTION_NAME", "csa-corpus-storage"),
    )
    parser.add_argument("--agent-name", default=os.environ.get("AGENT_NAME"))
    parser.add_argument("--agent-version", default=os.environ.get("AGENT_VERSION"))
    parser.add_argument("--eval-name", default="csa-agent-cloud-eval")
    parser.add_argument("--run-name", default=None)
    parser.add_argument("--poll-seconds", type=int, default=15)
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument(
        "--with-safety",
        action="store_true",
        help="Also attach builtin.violence (may be unavailable in some regions)",
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Require --dataset-id; do not upload --dataset-file",
    )
    args = parser.parse_args()

    if not args.project_endpoint:
        print("FOUNDRY_PROJECT_ENDPOINT / --project-endpoint is required", file=sys.stderr)
        return 1
    if not args.model:
        print("CHAT_DEPLOYMENT / --model is required (judge deployment)", file=sys.stderr)
        return 1

    deploy = load_last_deploy()
    agent_name = args.agent_name or deploy.get("name") or "cloud-devops-standards-assistant"
    agent_version = args.agent_version or deploy.get("version")

    from azure.ai.projects import AIProjectClient

    credential = DefaultAzureCredential()
    project_client = AIProjectClient(endpoint=args.project_endpoint, credential=credential)

    dataset_id = args.dataset_id
    if not dataset_id:
        if args.skip_upload:
            print("--dataset-id is required when --skip-upload is set", file=sys.stderr)
            return 1
        if not args.dataset_file.is_file():
            print(f"Dataset file not found: {args.dataset_file}", file=sys.stderr)
            return 1
        dataset = project_client.datasets.upload_file(
            name=args.dataset_name,
            version=args.dataset_version,
            file_path=str(args.dataset_file),
            connection_name=args.connection_name,
        )
        dataset_id = dataset.id
        print(f"Uploaded dataset id={dataset_id} name={args.dataset_name} version={args.dataset_version}")

    item_schema = {
        "type": "object",
        "properties": {
            "query": {"type": "string"},
            "id": {"type": "string"},
            "category": {"type": "string"},
            "difficulty": {"type": "string"},
            "source": {"type": "string"},
            "ground_truth": {"type": "string"},
            "defer": {"type": "boolean"},
            "out_of_scope": {"type": "boolean"},
        },
        "required": ["query"],
    }

    testing_criteria = build_testing_criteria(args.model, with_safety=args.with_safety)
    rest = FoundryEvalsRest(args.project_endpoint, credential)
    try:
        evaluation = rest.create_eval(
            {
                "name": args.eval_name,
                "data_source_config": {
                    "type": "custom",
                    "item_schema": item_schema,
                    "include_sample_schema": True,
                },
                "testing_criteria": testing_criteria,
            }
        )
        evaluation_id = evaluation["id"]
        print(f"Evaluation created: {evaluation_id}")

        target: dict = {"type": "azure_ai_agent", "name": agent_name}
        if agent_version:
            target["version"] = str(agent_version)

        run_name = args.run_name or f"smoke-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
        eval_run = rest.create_run(
            evaluation_id,
            {
                "name": run_name,
                "data_source": {
                    "type": "azure_ai_target_completions",
                    "source": {"type": "file_id", "id": dataset_id},
                    "input_messages": {
                        "type": "template",
                        "template": [
                            {
                                "type": "message",
                                "role": "user",
                                "content": {"type": "input_text", "text": "{{item.query}}"},
                            }
                        ],
                    },
                    "target": target,
                },
            },
        )
        run_id = eval_run["id"]
        print(f"Evaluation run started: {run_id}")

        deadline = time.time() + args.timeout_seconds
        status = eval_run.get("status")
        while status in (None, "queued", "in_progress", "running", "pending"):
            if time.time() > deadline:
                print(f"Timed out waiting for run {run_id} (last status={status})", file=sys.stderr)
                return 1
            time.sleep(args.poll_seconds)
            eval_run = rest.get_run(evaluation_id, run_id)
            status = eval_run.get("status")
            print(f"  status={status}")
    finally:
        rest.close()

    report_url = eval_run.get("report_url") or eval_run.get("result_urls") or eval_run.get("result_url")
    if isinstance(report_url, list):
        report_url = report_url[0] if report_url else None
    summary = {
        "evaluation_id": evaluation_id,
        "run_id": run_id,
        "status": status,
        "report_url": report_url,
        "dataset_id": dataset_id,
        "agent_name": agent_name,
        "agent_version": agent_version,
        "model": args.model,
        "run_name": run_name,
        "transport": "rest-httpx",
    }
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = RESULTS_DIR / "foundry-eval-latest.json"
    out_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    if report_url:
        print(f"Report URL: {report_url}")
    if status not in ("completed", "succeeded", "failed", "cancelled"):
        return 1
    if status == "failed" and not report_url:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
