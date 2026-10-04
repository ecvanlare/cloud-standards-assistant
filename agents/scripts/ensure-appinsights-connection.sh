#!/usr/bin/env bash
# Ensure Foundry project has an Application Insights connection (agent Traces / Monitor).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

load_tf_outputs
require_cmd az
require_cmd jq

APPINSIGHTS_CONNECTION_NAME="${APPINSIGHTS_CONNECTION_NAME:-csa-appinsights}"

pushd "${TF_ENV_DIR}" >/dev/null
APPINSIGHTS_NAME="$(terraform output -raw application_insights_name)"
APPINSIGHTS_CONNECTION_STRING="$(terraform output -raw application_insights_connection_string)"
popd >/dev/null

APPINSIGHTS_ID="$(az resource show \
  --resource-group "${RG}" \
  --name "${APPINSIGHTS_NAME}" \
  --resource-type Microsoft.Insights/components \
  --query id -o tsv)"

CONN_URL="https://management.azure.com${FOUNDRY_PROJECT_ID}/connections/${APPINSIGHTS_CONNECTION_NAME}?api-version=2025-06-01"

# Body carries the connection string; keep it off argv and out of logs.
body_file="$(mktemp)"
chmod 600 "${body_file}"
trap 'rm -f "${body_file}"' EXIT

jq -n \
  --arg name "${APPINSIGHTS_CONNECTION_NAME}" \
  --arg rid "${APPINSIGHTS_ID}" \
  --arg key "${APPINSIGHTS_CONNECTION_STRING}" \
  '{
    name: $name,
    properties: {
      category: "AppInsights",
      target: $rid,
      authType: "ApiKey",
      isSharedToAll: true,
      credentials: { key: $key },
      metadata: {
        ApiType: "Azure",
        ResourceId: $rid
      }
    }
  }' > "${body_file}"
unset APPINSIGHTS_CONNECTION_STRING

echo "Upserting project connection ${APPINSIGHTS_CONNECTION_NAME} -> ${APPINSIGHTS_NAME}"
az rest --method put --url "${CONN_URL}" --body "@${body_file}" --headers "Content-Type=application/json" -o json \
  | jq '{name: .name, category: .properties.category, authType: .properties.authType}'

echo "Done. Connection name: ${APPINSIGHTS_CONNECTION_NAME}"
