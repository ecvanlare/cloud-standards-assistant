#!/usr/bin/env bash
# Shared helpers for agent scripts. Expects TF_ENV_DIR (default: terraform/envs/dev).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENTS_DIR="${ROOT}/agents"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/dev}"
SEARCH_CONNECTION_NAME="${SEARCH_CONNECTION_NAME:-csa-ai-search}"
INDEX_NAME="${INDEX_NAME:-corpus-tuned}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

load_tf_outputs() {
  require_cmd terraform
  require_cmd az
  require_cmd jq

  pushd "${TF_ENV_DIR}" >/dev/null
  FOUNDRY_PROJECT_ENDPOINT="$(terraform output -raw foundry_project_endpoint 2>/dev/null || true)"
  if [[ -z "${FOUNDRY_PROJECT_ENDPOINT}" ]]; then
    local account project
    account="$(terraform output -raw foundry_account_name)"
    project="$(terraform output -raw foundry_project_name)"
    FOUNDRY_PROJECT_ENDPOINT="https://${account}.services.ai.azure.com/api/projects/${project}"
  fi
  FOUNDRY_ACCOUNT_NAME="$(terraform output -raw foundry_account_name)"
  FOUNDRY_PROJECT_NAME="$(terraform output -raw foundry_project_name)"
  FOUNDRY_PROJECT_ID="$(terraform output -raw foundry_project_id)"
  CHAT_DEPLOYMENT="$(terraform output -raw chat_deployment_name)"
  SEARCH_ENDPOINT="$(terraform output -raw search_endpoint)"
  RG="$(terraform output -raw resource_group_name)"
  popd >/dev/null

  SEARCH_NAME="${SEARCH_ENDPOINT#https://}"
  SEARCH_NAME="${SEARCH_NAME%.search.windows.net}"
  SEARCH_RESOURCE_ID="$(az search service show --name "${SEARCH_NAME}" --resource-group "${RG}" --query id -o tsv)"
  LOCATION="$(az group show --name "${RG}" --query location -o tsv)"
}
