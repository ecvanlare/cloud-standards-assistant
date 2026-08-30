#!/usr/bin/env bash
# Reset and run both corpus indexers; poll until success or failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

load_tf_outputs

run_indexer() {
  local name="$1"
  local token
  token="$(search_token)"
  echo "Reset ${name}"
  curl -sS -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Length: 0" \
    "${SEARCH_ENDPOINT}/indexers/${name}/reset?api-version=${SEARCH_API_VERSION}" >/dev/null || true
  echo "Run ${name}"
  curl -sS -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Length: 0" \
    "${SEARCH_ENDPOINT}/indexers/${name}/run?api-version=${SEARCH_API_VERSION}"
  echo
}

wait_indexer() {
  local name="$1"
  local status="running"
  local i=0
  while [[ "${status}" == "running" || "${status}" == "inProgress" ]]; do
    sleep 5
    i=$((i + 1))
    if (( i > 120 )); then
      echo "Timeout waiting for ${name}" >&2
      return 1
    fi
    local token
    token="$(search_token)"
    status="$(curl -sS -H "Authorization: Bearer ${token}" \
      "${SEARCH_ENDPOINT}/indexers/${name}/status?api-version=${SEARCH_API_VERSION}" \
      | jq -r '.lastResult.status // .status')"
    echo "${name}: ${status}"
    if [[ "${status}" == "success" ]]; then
      return 0
    fi
    if [[ "${status}" == "transientFailure" || "${status}" == "persistentFailure" || "${status}" == "fail" ]]; then
      curl -sS -H "Authorization: Bearer ${token}" \
        "${SEARCH_ENDPOINT}/indexers/${name}/status?api-version=${SEARCH_API_VERSION}" | jq .
      return 1
    fi
  done
}

run_indexer corpus-indexer-default
run_indexer corpus-indexer-tuned
wait_indexer corpus-indexer-default
wait_indexer corpus-indexer-tuned
echo "Indexers finished."
