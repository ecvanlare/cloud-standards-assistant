#!/usr/bin/env python3
"""Export golden_set.jsonl to Foundry Evaluation JSONL (query + metadata)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

EVAL_DIR = Path(__file__).resolve().parents[1]
DEFAULT_GOLDEN = EVAL_DIR / "golden_set.jsonl"
DEFAULT_OUT = EVAL_DIR / "results" / "foundry-dataset.jsonl"


def load_rows(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open(encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{path}:{line_no}: invalid JSON: {exc}") from exc
    return rows


def to_foundry_row(row: dict, *, exclude_out_of_scope: bool) -> dict | None:
    category = (row.get("category") or "").strip()
    ground_truth = row.get("ground_truth") or ""
    is_oos = category == "out-of-scope" or str(ground_truth).upper().startswith("OUT OF SCOPE")
    if exclude_out_of_scope and is_oos:
        return None

    query = (row.get("question") or "").strip()
    if not query:
        raise SystemExit(f"Row {row.get('id')!r} missing question")

    out: dict = {
        "query": query,
        "id": row.get("id"),
        "category": category,
        "difficulty": row.get("difficulty"),
        "source": row.get("source"),
        "ground_truth": ground_truth,
    }
    if is_oos:
        out["defer"] = True
        out["out_of_scope"] = True
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_GOLDEN)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--limit", type=int, default=0, help="Max rows (0 = all)")
    parser.add_argument(
        "--include-out-of-scope",
        action="store_true",
        help="Keep out-of-scope rows (tagged defer=true). Default: exclude them.",
    )
    args = parser.parse_args()

    rows = load_rows(args.input)
    written = 0
    skipped_oos = 0
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.output.open("w", encoding="utf-8") as out:
        for row in rows:
            converted = to_foundry_row(row, exclude_out_of_scope=not args.include_out_of_scope)
            if converted is None:
                skipped_oos += 1
                continue
            out.write(json.dumps(converted, ensure_ascii=False) + "\n")
            written += 1
            if args.limit and written >= args.limit:
                break

    print(
        json.dumps(
            {
                "input": str(args.input),
                "output": str(args.output),
                "written": written,
                "skipped_out_of_scope": skipped_oos,
                "include_out_of_scope": args.include_out_of_scope,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
