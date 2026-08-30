#!/usr/bin/env bash
# Create or update AI Search indexes, datasource, skillsets, and indexers for default + tuned.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

load_tf_outputs
export FOUNDRY_ENDPOINT EMBEDDING_DEPLOYMENT STORAGE_RESOURCE_ID CORPUS_CONTAINER

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

echo "Search: ${SEARCH_ENDPOINT}"
echo "Foundry: ${FOUNDRY_ENDPOINT}"
echo "Storage: ${STORAGE_RESOURCE_ID}"

for index_name in corpus-default corpus-tuned; do
  render_template "${SEARCH_DIR}/index.json" "${work}/${index_name}.json" "${index_name}"
  echo "PUT index ${index_name}"
  put_search_json "/indexes/${index_name}" "${work}/${index_name}.json"
done

render_template "${SEARCH_DIR}/datasource.json" "${work}/datasource.json"
echo "PUT datasource corpus-blobs"
put_search_json "/datasources/corpus-blobs" "${work}/datasource.json"

for skill in skillset-default skillset-tuned; do
  render_template "${SEARCH_DIR}/${skill}.json" "${work}/${skill}.json"
  name="$(jq -r .name "${work}/${skill}.json")"
  echo "PUT skillset ${name}"
  put_search_json "/skillsets/${name}" "${work}/${skill}.json"
done

for indexer in indexer-default indexer-tuned; do
  render_template "${SEARCH_DIR}/${indexer}.json" "${work}/${indexer}.json"
  name="$(jq -r .name "${work}/${indexer}.json")"
  echo "PUT indexer ${name}"
  put_search_json "/indexers/${name}" "${work}/${indexer}.json"
done

echo "Deploy finished."
