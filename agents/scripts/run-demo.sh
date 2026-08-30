#!/usr/bin/env bash
# Ask the deployed agent a question and print answer + run-step summary.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

require_cmd python3
load_tf_outputs

QUESTION="${1:-Compare what the Azure Security Benchmark and the Well-Architected Framework each say about network segmentation.}"
OUT_JSON="${2:-}"

export FOUNDRY_PROJECT_ENDPOINT="${FOUNDRY_PROJECT_ENDPOINT}"

python3 -m pip install --quiet --disable-pip-version-check \
  "azure-identity" "azure-ai-projects>=2.0.0" "openai" >/dev/null

args=(
  --project-endpoint "${FOUNDRY_PROJECT_ENDPOINT}"
  --question "${QUESTION}"
)
if [[ -n "${OUT_JSON}" ]]; then
  args+=(--out-json "${OUT_JSON}")
fi

python3 "${SCRIPT_DIR}/run_demo.py" "${args[@]}"
