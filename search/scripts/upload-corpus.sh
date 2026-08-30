#!/usr/bin/env bash
# Upload local corpus/ tree to the env corpus blob container with citation metadata.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

load_tf_outputs
require_cmd jq

manifest="${SEARCH_DIR}/corpus-manifest.json"

# Deployer typically has control-plane rights but not blob data-plane RBAC yet.
# Use account key for local ingest; Search indexer still uses MI at query/index time.
STORAGE_KEY="$(az storage account keys list \
  --account-name "${STORAGE_ACCOUNT}" \
  --resource-group "${RG}" \
  --query '[0].value' -o tsv)"

# AI Search enrichment drops awkward metadata; keep values simple ASCII (spaces -> _).
sanitize() {
  python3 -c 'import sys; print(sys.argv[1].replace(" ", "_").replace("/", "-"))' "$1"
}

upload_one() {
  local file="$1"
  local blob_path="$2"
  local framework="$3"
  local section="$4"
  local title="$5"

  local fw sec ttl
  fw="$(sanitize "${framework}")"
  sec="$(sanitize "${section}")"
  ttl="$(sanitize "${title}")"

  echo "Uploading ${blob_path} (${fw} / ${sec})"
  az storage blob upload \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_KEY}" \
    --auth-mode key \
    --container-name "${CORPUS_CONTAINER}" \
    --file "${file}" \
    --name "${blob_path}" \
    --overwrite true \
    --content-type "text/plain" \
    --metadata "citeframework=${fw}" "citesection=${sec}" "citetitle=${ttl}" \
    >/dev/null

  # Force metadata update in case upload coalescing dropped keys.
  az storage blob metadata update \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_KEY}" \
    --auth-mode key \
    --container-name "${CORPUS_CONTAINER}" \
    --name "${blob_path}" \
    --metadata "citeframework=${fw}" "citesection=${sec}" "citetitle=${ttl}" \
    >/dev/null
}

count="$(jq '.documents | length' "${manifest}")"
for i in $(seq 0 $((count - 1))); do
  rel="$(jq -r ".documents[$i].relative_path" "${manifest}")"
  file="${CORPUS_DIR}/${rel}"
  if [[ ! -f "${file}" ]]; then
    echo "SKIP missing ${file} (run fetch-corpus.sh first)" >&2
    continue
  fi
  upload_one "${file}" "${rel}" \
    "$(jq -r ".documents[$i].framework" "${manifest}")" \
    "$(jq -r ".documents[$i].section" "${manifest}")" \
    "$(jq -r ".documents[$i].title" "${manifest}")"
done

if [[ -d "${CORPUS_DIR}/cis" ]]; then
  while IFS= read -r -d '' file; do
    rel="cis/$(basename "${file}")"
    upload_one "${file}" "${rel}" "CIS_Benchmarks_for_Azure" "$(basename "${file}")" "$(basename "${file}")"
  done < <(find "${CORPUS_DIR}/cis" -type f \( -name '*.pdf' -o -name '*.md' -o -name '*.txt' -o -name '*.html' \) -print0 2>/dev/null || true)
fi

echo "Upload complete to ${STORAGE_ACCOUNT}/${CORPUS_CONTAINER}"
