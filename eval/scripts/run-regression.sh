#!/usr/bin/env bash
# Regression gate: schema always; optional repo live eval and/or Foundry cloud eval.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
ROOT="$(cd "${ROOT}" && pwd)"
cd "${ROOT}"

python3 eval/scripts/validate-golden-set.py --min-rows 50

LIVE="${RUN_LIVE_EVAL:-0}"
CLOUD="${RUN_FOUNDRY_CLOUD_EVAL:-0}"

if [[ "${LIVE}" != "1" && "${CLOUD}" != "1" ]]; then
  echo "Schema OK."
  echo "  RUN_LIVE_EVAL=1              → repo agent + judge (needs FOUNDRY_* env)"
  echo "  RUN_FOUNDRY_CLOUD_EVAL=1     → Foundry Evaluations tab (loads TF outputs)"
  echo "  Both flags can be set together."
  exit 0
fi

LIMIT="${EVAL_LIMIT:-10}"

if [[ "${LIVE}" == "1" ]]; then
  : "${FOUNDRY_PROJECT_ENDPOINT:?}"
  : "${FOUNDRY_ENDPOINT:?}"
  python3 -m pip install --quiet --disable-pip-version-check \
    "azure-identity" "azure-ai-projects>=2.0.0" "azure-ai-evaluation" "openai" >/dev/null
  python3 eval/scripts/run_eval.py --limit "${LIMIT}"
  echo "Repo live eval complete. See eval/results/latest-summary.json"
fi

if [[ "${CLOUD}" == "1" ]]; then
  EVAL_LIMIT="${LIMIT}" ./eval/scripts/run-foundry-eval.sh
  echo "Foundry cloud eval complete. See eval/results/foundry-eval-latest.json"
fi
