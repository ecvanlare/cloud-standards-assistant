#!/usr/bin/env bash
# Ensure Foundry project has an AAD connection to Azure AI Search (management plane).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

load_tf_outputs
require_cmd az
require_cmd jq

CONN_URL="https://management.azure.com${FOUNDRY_PROJECT_ID}/connections/${SEARCH_CONNECTION_NAME}?api-version=2025-06-01"

body="$(jq -n \
  --arg name "${SEARCH_CONNECTION_NAME}" \
  --arg target "${SEARCH_ENDPOINT}" \
  --arg rid "${SEARCH_RESOURCE_ID}" \
  --arg loc "${LOCATION}" \
  '{
    name: $name,
    properties: {
      category: "CognitiveSearch",
      target: $target,
      authType: "AAD",
      isSharedToAll: true,
      metadata: {
        ApiType: "Azure",
        ResourceId: $rid,
        location: $loc
      }
    }
  }')"

echo "Upserting project connection ${SEARCH_CONNECTION_NAME} -> ${SEARCH_ENDPOINT}"
az rest --method put --url "${CONN_URL}" --body "${body}" --headers "Content-Type=application/json" -o json \
  | jq '{name: .name, category: .properties.category, target: .properties.target, authType: .properties.authType}'

echo "Done. Connection name: ${SEARCH_CONNECTION_NAME}"
