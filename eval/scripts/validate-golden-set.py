#!/usr/bin/env python3
"""Validate eval/golden_set.jsonl schema, IDs, and minimum size."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PATH = ROOT / "eval" / "golden_set.jsonl"
REQUIRED = {"id", "question", "ground_truth", "source", "category", "difficulty"}
CATEGORIES = {
    "well-architected",
    "asb",
    "nist",
    "terraform",
    "cross-source",
    "out-of-scope",
}
DIFFICULTIES = {"easy", "medium", "hard"}
ID_RE = re.compile(r"^AZP-EVAL-\d{3}$")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", type=Path, default=DEFAULT_PATH)
    parser.add_argument("--min-rows", type=int, default=50)
    args = parser.parse_args()

    if not args.path.exists():
        print(f"missing {args.path}", file=sys.stderr)
        return 1

    rows = []
    errors = []
    for i, line in enumerate(args.path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"line {i}: invalid JSON ({exc})")
            continue
        rows.append((i, row))

    if len(rows) < args.min_rows:
        errors.append(f"need ≥{args.min_rows} rows, found {len(rows)}")

    seen_ids: set[str] = set()
    for i, row in rows:
        missing = REQUIRED - set(row)
        if missing:
            errors.append(f"line {i}: missing {sorted(missing)}")
            continue
        rid = row["id"]
        if not ID_RE.match(rid):
            errors.append(f"line {i}: bad id {rid!r}")
        if rid in seen_ids:
            errors.append(f"line {i}: duplicate id {rid}")
        seen_ids.add(rid)
        if row["category"] not in CATEGORIES:
            errors.append(f"line {i}: bad category {row['category']!r}")
        if row["difficulty"] not in DIFFICULTIES:
            errors.append(f"line {i}: bad difficulty {row['difficulty']!r}")
        gt = (row.get("ground_truth") or "").strip()
        if not gt:
            errors.append(f"line {i}: empty ground_truth")
        if "PLACEHOLDER" in gt:
            errors.append(f"line {i}: PLACEHOLDER ground_truth not allowed for regression gate")
        if not (row.get("question") or "").strip():
            errors.append(f"line {i}: empty question")

    hist = Counter(r["category"] for _, r in rows)
    print(f"rows={len(rows)} categories={dict(hist)}")
    if errors:
        print("FAIL", file=sys.stderr)
        for e in errors[:50]:
            print(f"- {e}", file=sys.stderr)
        if len(errors) > 50:
            print(f"... and {len(errors) - 50} more", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
