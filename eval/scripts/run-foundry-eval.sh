#!/usr/bin/env bash
# Export smoke rows, ensure storage connection, upload dataset, run Foundry cloud eval.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

LIMIT="${EVAL_LIMIT:-8}"
DATASET_NAME="${FOUNDRY_DATASET_NAME:-csa-golden-smoke}"

load_tf_outputs
export FOUNDRY_PROJECT_ENDPOINT CHAT_DEPLOYMENT STORAGE_CONNECTION_NAME

python3 -m pip install --quiet --disable-pip-version-check \
  "azure-identity" "azure-ai-projects>=2.0.0" "azure-storage-blob" "httpx" >/dev/null

echo "== Ensure storage connection (${STORAGE_CONNECTION_NAME}) =="
"${SCRIPT_DIR}/ensure-storage-connection.sh"

OUT_FILE="${EVAL_DIR}/results/foundry-dataset.jsonl"
echo "== Export golden → Foundry JSONL (limit=${LIMIT}, exclude out-of-scope) =="
python3 "${SCRIPT_DIR}/export-foundry-dataset.py" \
  --limit "${LIMIT}" \
  --output "${OUT_FILE}"

echo "== Run Foundry cloud eval =="
python3 "${SCRIPT_DIR}/run-foundry-eval.py" \
  --project-endpoint "${FOUNDRY_PROJECT_ENDPOINT}" \
  --model "${CHAT_DEPLOYMENT}" \
  --dataset-file "${OUT_FILE}" \
  --dataset-name "${DATASET_NAME}" \
  --connection-name "${STORAGE_CONNECTION_NAME}" \
  "$@"

echo "Done. Summary: ${EVAL_DIR}/results/foundry-eval-latest.json"
echo "Open the Foundry project → Evaluations tab to view the run."
