#!/usr/bin/env bash
# Regression gate: schema validation always; optional live eval when Azure env is set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

python3 eval/scripts/validate-golden-set.py --min-rows 50

if [[ "${RUN_LIVE_EVAL:-0}" != "1" ]]; then
  echo "Schema OK. Set RUN_LIVE_EVAL=1 (with FOUNDRY_* env) to run agent + evaluators."
  exit 0
fi

: "${FOUNDRY_PROJECT_ENDPOINT:?}"
: "${FOUNDRY_ENDPOINT:?}"

LIMIT="${EVAL_LIMIT:-10}"
python3 -m pip install --quiet --disable-pip-version-check \
  "azure-identity" "azure-ai-projects>=2.0.0" "azure-ai-evaluation" "openai" >/dev/null

python3 eval/scripts/run_eval.py --limit "${LIMIT}"
echo "Live eval complete. See eval/results/latest-summary.json"
