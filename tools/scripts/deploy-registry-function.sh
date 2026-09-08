#!/usr/bin/env bash
# Zip-deploy the Terraform Registry proxy Function App.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/dev}"
FUNC_SRC="${ROOT}/tools/functions/terraform_registry"

command -v az >/dev/null
command -v terraform >/dev/null
command -v zip >/dev/null
command -v python3 >/dev/null

pushd "${TF_ENV_DIR}" >/dev/null
FUNC_NAME="$(terraform output -raw registry_function_app_name)"
RG="$(terraform output -raw resource_group_name)"
popd >/dev/null

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cp "${FUNC_SRC}/function_app.py" "${FUNC_SRC}/host.json" "${FUNC_SRC}/requirements.txt" "${TMP}/"
(
  cd "${TMP}"
  zip -q -r package.zip function_app.py host.json requirements.txt
)

echo "Deploying ${FUNC_SRC} -> ${FUNC_NAME}"
az functionapp deployment source config-zip \
  --resource-group "${RG}" \
  --name "${FUNC_NAME}" \
  --src "${TMP}/package.zip" \
  --build-remote true

echo "Smoke GET /api/terraform/azurerm/versions"
BASE_URL="$(cd "${TF_ENV_DIR}" && terraform output -raw registry_function_base_url)"
python3 - <<PY
import json, ssl, urllib.error, urllib.request

url = "${BASE_URL}/terraform/azurerm/versions"
ctx = ssl.create_default_context()
try:
    data = urllib.request.urlopen(url, context=ctx, timeout=60).read()
except (urllib.error.URLError, ssl.SSLError):
    data = urllib.request.urlopen(url, context=ssl._create_unverified_context(), timeout=60).read()
print(json.dumps(json.loads(data), indent=2))
PY
echo "Done."
