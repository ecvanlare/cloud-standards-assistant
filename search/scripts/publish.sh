#!/usr/bin/env bash
# Publish the corpus to Azure AI Search. These are data-plane calls with no Azure resource type,
# so they stay here rather than in Terraform.
#
#   search/scripts/publish.sh [fetch|upload|definitions|index|all]
#
# fetch needs only the internet. The other stages need `source scripts/tf-env.sh <env>` first
# and an operator role (Storage Blob Data Contributor, Search Service Contributor).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SEARCH_DIR="${ROOT}/search"
CORPUS_DIR="${ROOT}/corpus"
MANIFEST="${SEARCH_DIR}/corpus-manifest.json"
SEARCH_API_VERSION="${SEARCH_API_VERSION:-2024-07-01}"
INDEXER_TIMEOUT_SECONDS="${INDEXER_TIMEOUT_SECONDS:-600}"

for cmd in curl jq python3; do
  command -v "${cmd}" >/dev/null || { echo "Missing required command: ${cmd}" >&2; exit 1; }
done

manifest_rows() {
  jq -r '.documents[] | [.relative_path, .source_url, .framework, .section, .title] | @tsv' "${MANIFEST}"
}

fetch() {
  while IFS=$'\t' read -r rel url framework section title; do
    local out="${CORPUS_DIR}/${rel}" tmp
    mkdir -p "$(dirname "${out}")"
    tmp="$(mktemp)"
    echo "Fetch ${url}"
    if ! curl -fsSL -A "Mozilla/5.0 (compatible; cloud-standards-assistant-corpus-fetch/1.0)" -o "${tmp}" "${url}"; then
      echo "WARN: fetch failed for ${url}; keeping any existing file" >&2
      rm -f "${tmp}"
      continue
    fi
    python3 - "${tmp}" "${out}" "${url}" "${framework}" "${section}" "${title}" <<'PY'
import html
import re
import sys
from pathlib import Path

src, dest, url, framework, section, title = sys.argv[1:7]
text = Path(src).read_text(encoding="utf-8", errors="ignore")
for tag in ("script", "style", "nav", "footer"):
    text = re.sub(rf"(?is)<{tag}.*?>.*?</{tag}>", " ", text)
text = html.unescape(re.sub(r"(?s)<[^>]+>", " ", text))
text = re.sub(r"\n{3,}", "\n\n", re.sub(r"[ \t]+", " ", text)).strip()
header = f"Source-URL: {url}\nFramework: {framework}\nSection: {section}\nTitle: {title}\n\n"
Path(dest).write_text(header + text + "\n", encoding="utf-8")
PY
    rm -f "${tmp}"
  done < <(manifest_rows)
}

# AI Search enrichment drops awkward metadata; keep values simple ASCII.
metadata_value() {
  local value="${1// /_}"
  echo "${value//\//-}"
}

upload() {
  : "${STORAGE_ACCOUNT_NAME:?source scripts/tf-env.sh first}" "${CORPUS_CONTAINER:?}"
  while IFS=$'\t' read -r rel _url framework section title; do
    local file="${CORPUS_DIR}/${rel}"
    if [[ ! -f "${file}" ]]; then
      echo "SKIP missing ${file} (run the fetch stage first)" >&2
      continue
    fi
    echo "Upload ${rel}"
    az storage blob upload \
      --auth-mode login \
      --account-name "${STORAGE_ACCOUNT_NAME}" \
      --container-name "${CORPUS_CONTAINER}" \
      --file "${file}" \
      --name "${rel}" \
      --overwrite true \
      --content-type "text/plain" \
      --metadata "citeframework=$(metadata_value "${framework}")" \
      "citesection=$(metadata_value "${section}")" \
      "citetitle=$(metadata_value "${title}")" \
      --only-show-errors >/dev/null
  done < <(manifest_rows)
}

search_token() {
  az account get-access-token --resource https://search.azure.com --query accessToken -o tsv
}

search_call() {
  local method="$1" path="$2"
  shift 2
  curl -sS --fail-with-body -X "${method}" \
    -H "Authorization: Bearer $(search_token)" \
    -H "Content-Type: application/json" \
    "$@" \
    "${SEARCH_ENDPOINT}${path}?api-version=${SEARCH_API_VERSION}"
}

render() {
  sed \
    -e "s|__FOUNDRY_ENDPOINT__|${FOUNDRY_ENDPOINT%/}|g" \
    -e "s|__EMBEDDING_DEPLOYMENT__|${EMBEDDING_DEPLOYMENT}|g" \
    -e "s|__STORAGE_RESOURCE_ID__|${STORAGE_ACCOUNT_ID}|g" \
    -e "s|__CORPUS_CONTAINER__|${CORPUS_CONTAINER}|g" \
    -e "s|__INDEX_NAME__|${2:-}|g" \
    "$1"
}

put_definition() {
  local kind="$1" template="$2" name="${3:-}" body
  body="$(render "${SEARCH_DIR}/${template}" "${name}")"
  name="${name:-$(jq -r .name <<<"${body}")}"
  echo "PUT ${kind} ${name}"
  search_call PUT "/${kind}/${name}" --data-binary "${body}" >/dev/null
}

definitions() {
  : "${SEARCH_ENDPOINT:?source scripts/tf-env.sh first}" "${FOUNDRY_ENDPOINT:?}" "${EMBEDDING_DEPLOYMENT:?}" "${STORAGE_ACCOUNT_ID:?}"
  put_definition indexes index.json corpus-default
  put_definition indexes index.json corpus-tuned
  put_definition datasources datasource.json corpus-blobs
  put_definition skillsets skillset-default.json
  put_definition skillsets skillset-tuned.json
  put_definition indexers indexer-default.json
  put_definition indexers indexer-tuned.json
}

wait_indexer() {
  local name="$1" deadline=$((SECONDS + INDEXER_TIMEOUT_SECONDS)) status
  while (( SECONDS < deadline )); do
    sleep 10
    status="$(search_call GET "/indexers/${name}/status" | jq -r '.lastResult.status // .status')"
    echo "${name}: ${status}"
    case "${status}" in
      success) return 0 ;;
      transientFailure | persistentFailure | error)
        search_call GET "/indexers/${name}/status" | jq '.lastResult'
        return 1
        ;;
    esac
  done
  echo "Timed out waiting for ${name}" >&2
  return 1
}

# 409 means a run is already in progress; a new indexer starts one as soon as it is created.
indexer_action() {
  local name="$1" action="$2" code
  code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
    -H "Authorization: Bearer $(search_token)" \
    -H "Content-Length: 0" \
    "${SEARCH_ENDPOINT}/indexers/${name}/${action}?api-version=${SEARCH_API_VERSION}")"
  case "${code}" in
    2??) ;;
    409) echo "${name} is already running" ;;
    *)
      echo "${action} ${name} failed: HTTP ${code}" >&2
      return 1
      ;;
  esac
}

index() {
  : "${SEARCH_ENDPOINT:?source scripts/tf-env.sh first}"
  for name in corpus-indexer-default corpus-indexer-tuned; do
    echo "Reset and run ${name}"
    indexer_action "${name}" reset
    indexer_action "${name}" run
  done
  wait_indexer corpus-indexer-default
  wait_indexer corpus-indexer-tuned
}

stage="${1:-all}"
case "${stage}" in
  fetch | upload | definitions | index) "${stage}" ;;
  all)
    fetch
    upload
    definitions
    index
    ;;
  *)
    echo "Usage: $0 [fetch|upload|definitions|index|all]" >&2
    exit 1
    ;;
esac
