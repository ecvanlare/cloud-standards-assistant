#!/usr/bin/env bash
# Ensure Search connection, then create/update the Foundry agent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

require_cmd python3
load_tf_outputs

"${SCRIPT_DIR}/ensure-search-connection.sh"

export FOUNDRY_PROJECT_ENDPOINT CHAT_DEPLOYMENT SEARCH_CONNECTION_NAME INDEX_NAME FUNCTION_BASE_URL REGISTRY_FUNCTION_BASE_URL
FOUNDRY_PROJECT_ENDPOINT="${FOUNDRY_PROJECT_ENDPOINT}"
CHAT_DEPLOYMENT="${CHAT_DEPLOYMENT}"
SEARCH_CONNECTION_NAME="${SEARCH_CONNECTION_NAME}"
INDEX_NAME="${INDEX_NAME}"
FUNCTION_BASE_URL="${FUNCTION_BASE_URL}"
REGISTRY_FUNCTION_BASE_URL="${REGISTRY_FUNCTION_BASE_URL}"

if [[ -z "${FUNCTION_BASE_URL}" ]]; then
  echo "function_base_url Terraform output missing; apply the function_app module first." >&2
  exit 1
fi
if [[ -z "${REGISTRY_FUNCTION_BASE_URL}" ]]; then
  echo "registry_function_base_url Terraform output missing; apply function_apps map (reg) first." >&2
  exit 1
fi

python3 -m pip install --quiet --disable-pip-version-check \
  "azure-identity" "azure-ai-projects>=2.0.0" "openai" >/dev/null

python3 "${SCRIPT_DIR}/deploy_agent.py" \
  --project-endpoint "${FOUNDRY_PROJECT_ENDPOINT}" \
  --connection-name "${SEARCH_CONNECTION_NAME}" \
  --index-name "${INDEX_NAME}" \
  --model "${CHAT_DEPLOYMENT}" \
  --function-base-url "${FUNCTION_BASE_URL}" \
  --registry-function-base-url "${REGISTRY_FUNCTION_BASE_URL}"
