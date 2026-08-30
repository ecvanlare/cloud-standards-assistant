#!/usr/bin/env bash
# Ensure Search connection, then create/update the Foundry agent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

require_cmd python3
load_tf_outputs

"${SCRIPT_DIR}/ensure-search-connection.sh"

export FOUNDRY_PROJECT_ENDPOINT CHAT_DEPLOYMENT SEARCH_CONNECTION_NAME INDEX_NAME
FOUNDRY_PROJECT_ENDPOINT="${FOUNDRY_PROJECT_ENDPOINT}"
CHAT_DEPLOYMENT="${CHAT_DEPLOYMENT}"
SEARCH_CONNECTION_NAME="${SEARCH_CONNECTION_NAME}"
INDEX_NAME="${INDEX_NAME}"

python3 -m pip install --quiet --disable-pip-version-check \
  "azure-identity" "azure-ai-projects>=2.0.0" "openai" >/dev/null

python3 "${SCRIPT_DIR}/deploy_agent.py" \
  --project-endpoint "${FOUNDRY_PROJECT_ENDPOINT}" \
  --connection-name "${SEARCH_CONNECTION_NAME}" \
  --index-name "${INDEX_NAME}" \
  --model "${CHAT_DEPLOYMENT}"
