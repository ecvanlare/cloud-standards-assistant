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


def _criterion(name: str, evaluator_name: str, model_deployment: str, data_mapping: dict) -> dict:
    return {
        "type": "azure_ai_evaluator",
        "name": name,
        "evaluator_name": evaluator_name,
        "initialization_parameters": {"deployment_name": model_deployment},
        "data_mapping": data_mapping,
    }


def build_testing_criteria(
    model_deployment: str, *, with_safety: bool, with_agent_evaluators: bool
) -> list[dict]:
    query_response = {
        "query": "{{item.query}}",
        "response": "{{sample.output_text}}",
    }
    criteria: list[dict] = [
        _criterion("coherence", "builtin.coherence", model_deployment, query_response),
        _criterion("relevance", "builtin.relevance", model_deployment, query_response),
        _criterion(
            "response_completeness",
            "builtin.response_completeness",
            model_deployment,
            {"response": "{{sample.output_text}}", "ground_truth": "{{item.ground_truth}}"},
        ),
    ]
    if with_agent_evaluators:
        criteria.append(
            _criterion(
                "task_adherence",
                "builtin.task_adherence",
                model_deployment,
                {"query": "{{item.query}}", "response": "{{sample.output_items}}"},
            )
        )
        criteria.append(
            _criterion("intent_resolution", "builtin.intent_resolution", model_deployment, query_response)
        )
    if with_safety:
        criteria.append(_criterion("violence", "builtin.violence", model_deployment, query_response))
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


def _as_count(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _criterion_label(item: dict) -> str | None:
    for key in ("testing_criteria", "name", "evaluator_name", "criterion"):
        value = item.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _rate_from_counts(item: dict) -> float | None:
    passed = _as_count(item.get("passed"))
    failed = _as_count(item.get("failed"))
    if passed is None or failed is None:
        return None
    total = passed + failed
    if total <= 0:
        return None
    return 100.0 * passed / total


def pass_rates(eval_run: dict) -> dict[str, float | None]:
    """Pass rate (0–100) per criterion, from whatever list the run payload returns."""
    lists: list[list] = []
    containers: list[dict] = [eval_run]
    for key in ("result", "results_summary", "summary"):
        nested = eval_run.get(key)
        if isinstance(nested, dict):
            containers.append(nested)
    list_keys = (
        "per_testing_criteria_results",
        "per_criteria_results",
        "testing_criteria_results",
        "criteria_results",
    )
    for container in containers:
        for key in list_keys:
            value = container.get(key)
            if isinstance(value, list):
                lists.append(value)
    rates: dict[str, float | None] = {}
    for items in lists:
        for item in items:
            if not isinstance(item, dict):
                continue
            label = _criterion_label(item)
            rate = _rate_from_counts(item)
            if label and rate is not None:
                rates[label] = rate
    return rates


def wait_for_run(
    rest: FoundryEvalsRest,
    evaluation_id: str,
    eval_run: dict,
    *,
    poll_seconds: int,
    timeout_seconds: int,
) -> dict | None:
    run_id = eval_run["id"]
    deadline = time.time() + timeout_seconds
    status = eval_run.get("status")
    while status in (None, "queued", "in_progress", "running", "pending"):
        if time.time() > deadline:
            print(f"Timed out waiting for run {run_id} (last status={status})", file=sys.stderr)
            print(f"Resume with --eval-id {evaluation_id} --run-id {run_id}", file=sys.stderr)
            return None
        time.sleep(poll_seconds)
        eval_run = rest.get_run(evaluation_id, run_id)
        status = eval_run.get("status")
        print(f"  status={status}")
    return eval_run


def redact_run(eval_run: dict) -> dict:
    """Drop bulky inputs. Leave score fields intact. URLs stay in the gitignored file only."""
    drop = {"data_source", "input_messages", "metadata"}
    return {key: value for key, value in eval_run.items() if key not in drop}


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
    parser.add_argument("--timeout-seconds", type=int, default=7200)
    parser.add_argument(
        "--eval-id",
        default=None,
        help="With --run-id: resume polling an existing run instead of creating one",
    )
    parser.add_argument("--run-id", default=None)
    parser.add_argument(
        "--with-safety",
        action="store_true",
        help="Also attach builtin.violence (may be unavailable in some regions)",
    )
    parser.add_argument(
        "--with-agent-evaluators",
        action="store_true",
        help="Also attach builtin.task_adherence and builtin.intent_resolution",
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Require --dataset-id; do not upload --dataset-file",
    )
    parser.add_argument(
        "--gate",
        type=Path,
        default=None,
        help="JSON of minimum pass rates per evaluator; exit 2 if any is missed",
    )
    args = parser.parse_args()

    if not args.project_endpoint:
        print("FOUNDRY_PROJECT_ENDPOINT / --project-endpoint is required", file=sys.stderr)
        return 1
    if not args.model:
        print("CHAT_DEPLOYMENT / --model is required (judge deployment)", file=sys.stderr)
        return 1
    if bool(args.eval_id) != bool(args.run_id):
        print("--eval-id and --run-id must be set together", file=sys.stderr)
        return 1

    deploy = load_last_deploy()
    agent_name = args.agent_name or deploy.get("name") or "cloud-devops-standards-assistant"
    agent_version = args.agent_version or deploy.get("version")

    credential = DefaultAzureCredential()

    if args.run_id:
        rest = FoundryEvalsRest(args.project_endpoint, credential)
        try:
            eval_run = rest.get_run(args.eval_id, args.run_id)
            print(f"Resuming run {args.run_id} (status={eval_run.get('status')})")
            eval_run = wait_for_run(
                rest,
                args.eval_id,
                eval_run,
                poll_seconds=args.poll_seconds,
                timeout_seconds=args.timeout_seconds,
            )
        finally:
            rest.close()
        if eval_run is None:
            return 1
        data_source = eval_run.get("data_source") or {}
        target = data_source.get("target") or {}
        return write_summary(
            args,
            eval_run,
            evaluation_id=args.eval_id,
            run_name=args.run_name or eval_run.get("name") or args.run_id,
            dataset_id=(data_source.get("source") or {}).get("id"),
            agent_name=target.get("name") or agent_name,
            agent_version=target.get("version") or agent_version,
        )

    from azure.ai.projects import AIProjectClient

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

    testing_criteria = build_testing_criteria(
        args.model,
        with_safety=args.with_safety,
        with_agent_evaluators=args.with_agent_evaluators,
    )
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
        print(f"Evaluation run started: {eval_run['id']}")
        eval_run = wait_for_run(
            rest,
            evaluation_id,
            eval_run,
            poll_seconds=args.poll_seconds,
            timeout_seconds=args.timeout_seconds,
        )
    finally:
        rest.close()
    if eval_run is None:
        return 1
    return write_summary(
        args,
        eval_run,
        evaluation_id=evaluation_id,
        run_name=run_name,
        dataset_id=dataset_id,
        agent_name=agent_name,
        agent_version=agent_version,
    )


def write_summary(
    args: argparse.Namespace,
    eval_run: dict,
    *,
    evaluation_id: str,
    run_name: str,
    dataset_id: str | None,
    agent_name: str,
    agent_version: str | None,
) -> int:
    run_id = eval_run["id"]
    status = eval_run.get("status")
    report_url = eval_run.get("report_url") or eval_run.get("result_urls") or eval_run.get("result_url")
    if isinstance(report_url, list):
        report_url = report_url[0] if report_url else None
    rates = pass_rates(eval_run)
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
        "pass_rates": rates,
        "run": redact_run(eval_run),
    }
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(summary, indent=2) + "\n"
    out_path = RESULTS_DIR / "foundry-eval-latest.json"
    out_path.write_text(payload, encoding="utf-8")
    stamp_path = RESULTS_DIR / f"foundry-eval-{run_name}.json"
    stamp_path.write_text(payload, encoding="utf-8")
    printable = {key: value for key, value in summary.items() if key not in ("report_url", "run")}
    print(json.dumps(printable, indent=2))
    print(f"Wrote {out_path}")
    if rates:
        print("pass_rates: " + ", ".join(f"{name}={rate:.1f}%" for name, rate in rates.items() if rate is not None))
    if status not in ("completed", "succeeded", "failed", "cancelled"):
        return 1
    if status == "failed" and not report_url:
        return 1
    if args.gate:
        return check_gate(status, rates, args.gate)
    return 0


def check_gate(status: str | None, rates: dict[str, float | None], thresholds_path: Path) -> int:
    if status not in ("completed", "succeeded"):
        print(f"Gate failed: run status {status}", file=sys.stderr)
        return 2
    thresholds = json.loads(thresholds_path.read_text(encoding="utf-8"))
    failures = []
    for name, minimum in thresholds.items():
        rate = rates.get(name)
        if rate is None or rate < minimum:
            failures.append(f"{name}={'n/a' if rate is None else f'{rate:.1f}%'} (min {minimum}%)")
    if failures:
        print("Gate failed: " + ", ".join(failures), file=sys.stderr)
        return 2
    print(f"Gate passed ({thresholds_path.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
