#!/usr/bin/env bash
# Shared helpers for search scripts. Expects TF_ENV_DIR (default: terraform/envs/dev).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEARCH_DIR="${ROOT}/search"
CORPUS_DIR="${ROOT}/corpus"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/dev}"
SEARCH_API_VERSION="${SEARCH_API_VERSION:-2024-07-01}"

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
  require_cmd python3

  pushd "${TF_ENV_DIR}" >/dev/null
  SEARCH_ENDPOINT="$(terraform output -raw search_endpoint)"
  FOUNDRY_ENDPOINT="$(terraform output -raw foundry_endpoint)"
  EMBEDDING_DEPLOYMENT="$(terraform output -raw embedding_deployment_name)"
  STORAGE_ACCOUNT="$(terraform output -raw storage_account_name)"
  CORPUS_CONTAINER="$(terraform output -raw corpus_container_name)"
  RG="$(terraform output -raw resource_group_name)"
  popd >/dev/null

  STORAGE_RESOURCE_ID="$(az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RG}" --query id -o tsv)"
  SEARCH_NAME="${SEARCH_ENDPOINT#https://}"
  SEARCH_NAME="${SEARCH_NAME%.search.windows.net}"
}

search_token() {
  az account get-access-token --resource https://search.azure.com --query accessToken -o tsv
}

render_template() {
  local src="$1"
  local dest="$2"
  local index_name="${3:-}"
  python3 - "$src" "$dest" "$index_name" <<'PY'
import sys
src, dest, index_name = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(src, encoding="utf-8").read()
repl = {
    "__FOUNDRY_ENDPOINT__": __import__("os").environ["FOUNDRY_ENDPOINT"].rstrip("/"),
    "__EMBEDDING_DEPLOYMENT__": __import__("os").environ["EMBEDDING_DEPLOYMENT"],
    "__STORAGE_RESOURCE_ID__": __import__("os").environ["STORAGE_RESOURCE_ID"],
    "__CORPUS_CONTAINER__": __import__("os").environ["CORPUS_CONTAINER"],
    "__INDEX_NAME__": index_name or "",
}
for k, v in repl.items():
    text = text.replace(k, v)
open(dest, "w", encoding="utf-8").write(text)
PY
}

put_search_json() {
  local path="$1"
  local body_file="$2"
  local token
  token="$(search_token)"
  curl -sS -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d @"${body_file}" \
    "${SEARCH_ENDPOINT}${path}?api-version=${SEARCH_API_VERSION}"
  echo
}
