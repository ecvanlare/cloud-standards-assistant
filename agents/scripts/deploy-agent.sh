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

if [[ -z "${FUNCTION_BASE_URL}" ]]; then
  echo "function_base_url Terraform output missing; apply the function_app module first." >&2
  exit 1
fi
if [[ -z "${REGISTRY_FUNCTION_BASE_URL}" ]]; then
  echo "registry_function_base_url Terraform output missing; apply function_apps map (reg) first." >&2
  exit 1
fi

RAI_POLICY_NAME="${RAI_POLICY_NAME:-csa-blocking-medium}"
export RAI_POLICY_NAME

# Agent create expects the full ARM resource ID for custom policies.
SUB="$(az account show --query id -o tsv)"
RAI_POLICY_ID="/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY_ACCOUNT_NAME}/raiPolicies/${RAI_POLICY_NAME}"
export RAI_POLICY_ID

python3 -m pip install --quiet --disable-pip-version-check --user \
  "azure-identity" "azure-ai-projects>=2.0.0" "openai" >/dev/null 2>&1 || true

PYTHON_BIN="${PYTHON_BIN:-python3}"
if ! "${PYTHON_BIN}" -c "import azure.identity, azure.ai.projects" 2>/dev/null; then
  if /usr/bin/python3 -c "import azure.identity, azure.ai.projects" 2>/dev/null; then
    PYTHON_BIN=/usr/bin/python3
  else
    echo "Python azure-identity / azure-ai-projects not found. Set PYTHON_BIN or pip install --user." >&2
    exit 1
  fi
fi

"${PYTHON_BIN}" "${SCRIPT_DIR}/deploy_agent.py" \
  --project-endpoint "${FOUNDRY_PROJECT_ENDPOINT}" \
  --connection-name "${SEARCH_CONNECTION_NAME}" \
  --index-name "${INDEX_NAME}" \
  --model "${CHAT_DEPLOYMENT}" \
  --function-base-url "${FUNCTION_BASE_URL}" \
  --registry-function-base-url "${REGISTRY_FUNCTION_BASE_URL}" \
  --rai-policy-name "${RAI_POLICY_NAME}" \
  --rai-policy-id "${RAI_POLICY_ID}"
