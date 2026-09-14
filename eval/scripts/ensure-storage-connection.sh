#!/usr/bin/env bash
# Upsert Foundry project Azure Storage connection (Entra ID) for Datasets + Evaluations.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

load_tf_outputs
require_cmd az
require_cmd jq

CONN_URL="https://management.azure.com${FOUNDRY_PROJECT_ID}/connections/${STORAGE_CONNECTION_NAME}?api-version=2025-06-01"

body="$(jq -n \
  --arg name "${STORAGE_CONNECTION_NAME}" \
  --arg target "${STORAGE_BLOB_ENDPOINT}" \
  --arg rid "${STORAGE_RESOURCE_ID}" \
  --arg loc "${LOCATION}" \
  '{
    name: $name,
    properties: {
      category: "AzureStorageAccount",
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

echo "Upserting project connection ${STORAGE_CONNECTION_NAME} -> ${STORAGE_BLOB_ENDPOINT}"
az rest --method put --url "${CONN_URL}" --body "${body}" --headers "Content-Type=application/json" -o json \
  | jq '{name: .name, category: .properties.category, target: .properties.target, authType: .properties.authType}'

echo "Done. Connection name: ${STORAGE_CONNECTION_NAME}"
echo "Confirm project MI has Storage Blob Data Contributor on the storage account (identity module)."
