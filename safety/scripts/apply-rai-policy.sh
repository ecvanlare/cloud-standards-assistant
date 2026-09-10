#!/usr/bin/env bash
# Upsert custom RAI content-filter policy on the Foundry AI Services account
# and attach it to the chat deployment (prompt + completion Blocking @ Medium).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/dev}"
POLICY_NAME="${RAI_POLICY_NAME:-csa-blocking-medium}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd terraform
require_cmd az
require_cmd jq

pushd "${TF_ENV_DIR}" >/dev/null
ACCOUNT="$(terraform output -raw foundry_account_name)"
RG="$(terraform output -raw resource_group_name)"
DEPLOYMENT="$(terraform output -raw chat_deployment_name)"
popd >/dev/null

SUB="$(az account show --query id -o tsv)"
POLICY_URL="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT}/raiPolicies/${POLICY_NAME}?api-version=2025-06-01"
DEPLOY_URL="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.CognitiveServices/accounts/${ACCOUNT}/deployments/${DEPLOYMENT}?api-version=2025-06-01"

# User-managed Blocking policy: Medium harm filters on Prompt + Completion,
# plus Jailbreak (prompt) and Protected Material Text (completion).
body="$(jq -n --arg name "${POLICY_NAME}" '{
  name: $name,
  properties: {
    mode: "Blocking",
    basePolicyName: "Microsoft.DefaultV2",
    contentFilters: [
      { name: "Hate", enabled: true, blocking: true, severityThreshold: "Medium", source: "Prompt" },
      { name: "Hate", enabled: true, blocking: true, severityThreshold: "Medium", source: "Completion" },
      { name: "Sexual", enabled: true, blocking: true, severityThreshold: "Medium", source: "Prompt" },
      { name: "Sexual", enabled: true, blocking: true, severityThreshold: "Medium", source: "Completion" },
      { name: "Violence", enabled: true, blocking: true, severityThreshold: "Medium", source: "Prompt" },
      { name: "Violence", enabled: true, blocking: true, severityThreshold: "Medium", source: "Completion" },
      { name: "Selfharm", enabled: true, blocking: true, severityThreshold: "Medium", source: "Prompt" },
      { name: "Selfharm", enabled: true, blocking: true, severityThreshold: "Medium", source: "Completion" },
      { name: "Jailbreak", enabled: true, blocking: true, source: "Prompt" },
      { name: "Protected Material Text", enabled: true, blocking: true, source: "Completion" }
    ]
  }
}')"

echo "Upserting RAI policy ${POLICY_NAME} on ${ACCOUNT}"
az rest --method put --url "${POLICY_URL}" --body "${body}" --headers "Content-Type=application/json" -o json \
  | jq '{name: .name, mode: .properties.mode, filterCount: (.properties.contentFilters|length)}'

echo "Fetching deployment ${DEPLOYMENT} to set raiPolicyName"
deploy_get="$(az rest --method get --url "${DEPLOY_URL}" -o json)"
deploy_put="$(echo "${deploy_get}" | jq --arg pol "${POLICY_NAME}" '
  {
    sku: .sku,
    properties: (.properties | {model, versionUpgradeOption, raiPolicyName: $pol})
  }
')"

echo "Attaching policy ${POLICY_NAME} to deployment ${DEPLOYMENT}"
az rest --method put --url "${DEPLOY_URL}" --body "${deploy_put}" --headers "Content-Type=application/json" -o json \
  | jq '{name: .name, raiPolicyName: .properties.raiPolicyName, model: .properties.model.name}'

echo "Done. Export RAI_POLICY_NAME=${POLICY_NAME} for agent deploy."
