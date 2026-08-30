#!/usr/bin/env bash
# Hybrid query against corpus-default and corpus-tuned; prints citation fields.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

load_tf_outputs

QUERY="${1:-What does the Well-Architected Framework say about reliability zones?}"
TOP="${TOP:-3}"

search_index() {
  local index_name="$1"
  local token
  token="$(search_token)"
  local body
  body="$(jq -n \
    --arg q "${QUERY}" \
    --argjson top "${TOP}" \
    '{
      search: $q,
      top: $top,
      select: "chunk_id,framework,section,title,source_path,content",
      count: true,
      vectorQueries: [
        {
          kind: "text",
          text: $q,
          fields: "contentVector",
          k: $top
        }
      ]
    }')"
  echo "=== ${index_name} ==="
  curl -sS -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "${body}" \
    "${SEARCH_ENDPOINT}/indexes/${index_name}/docs/search?api-version=${SEARCH_API_VERSION}" \
    | jq '{count: .["@odata.count"], value: [.value[] | {score: .["@search.score"], framework, section, title, source_path, content: ((.content // "")[0:400])}]}'
}

search_index corpus-default
search_index corpus-tuned
