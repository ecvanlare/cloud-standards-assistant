#!/usr/bin/env python3
"""Upload a Foundry Evaluation JSONL file as a project dataset."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from azure.identity import DefaultAzureCredential

EVAL_DIR = Path(__file__).resolve().parents[1]
DEFAULT_FILE = EVAL_DIR / "results" / "foundry-dataset.jsonl"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-endpoint", default=os.environ.get("FOUNDRY_PROJECT_ENDPOINT"))
    parser.add_argument("--file", type=Path, default=DEFAULT_FILE)
    parser.add_argument("--name", default=os.environ.get("FOUNDRY_DATASET_NAME", "csa-golden-smoke"))
    parser.add_argument(
        "--version",
        default=os.environ.get("FOUNDRY_DATASET_VERSION")
        or datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S"),
    )
    parser.add_argument(
        "--connection-name",
        default=os.environ.get("STORAGE_CONNECTION_NAME", "csa-corpus-storage"),
        help="Azure Storage Account connection on the Foundry project",
    )
    args = parser.parse_args()

    if not args.project_endpoint:
        print("FOUNDRY_PROJECT_ENDPOINT / --project-endpoint is required", file=sys.stderr)
        return 1
    if not args.file.is_file():
        print(f"Dataset file not found: {args.file}", file=sys.stderr)
        return 1

    from azure.ai.projects import AIProjectClient

    credential = DefaultAzureCredential()
    client = AIProjectClient(endpoint=args.project_endpoint, credential=credential)
    dataset = client.datasets.upload_file(
        name=args.name,
        version=args.version,
        file_path=str(args.file),
        connection_name=args.connection_name,
    )

    payload = {
        "id": getattr(dataset, "id", None),
        "name": getattr(dataset, "name", args.name),
        "version": getattr(dataset, "version", args.version),
        "data_uri": getattr(dataset, "data_uri", None),
    }
    print(json.dumps(payload, indent=2))
    print(f"DATASET_ID={payload['id']}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
