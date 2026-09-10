#!/usr/bin/env bash
# Build/push the serving image to ACR, apply Terraform Container App, smoke health + ask + UI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/dev}"
SERVING_DIR="${ROOT}/serving"
IMAGE_TAG="${SERVING_IMAGE_TAG:-latest}"
REPO="csa-serving"
SKIP_TF="${SKIP_TF:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_ASK="${SKIP_ASK:-0}"

command -v az >/dev/null
command -v terraform >/dev/null
command -v python3 >/dev/null

pushd "${TF_ENV_DIR}" >/dev/null
terraform init -input=false >/dev/null

if [[ "${SKIP_TF}" != "1" ]]; then
  echo "Ensuring ACR exists..."
  terraform apply -input=false -auto-approve -target=module.acr
fi

ACR_NAME="$(terraform output -raw acr_name)"
ACR_LOGIN="$(terraform output -raw acr_login_server)"
RG="$(terraform output -raw resource_group_name)"
popd >/dev/null

IMAGE="${ACR_LOGIN}/${REPO}:${IMAGE_TAG}"

if [[ "${SKIP_BUILD}" != "1" ]]; then
  echo "Building ${IMAGE} via ACR Tasks..."
  az acr build \
    --registry "${ACR_NAME}" \
    --resource-group "${RG}" \
    --image "${REPO}:${IMAGE_TAG}" \
    --file "${SERVING_DIR}/Dockerfile" \
    "${SERVING_DIR}"
fi

if [[ "${SKIP_TF}" != "1" ]]; then
  echo "Applying Container App (and remaining stack)..."
  pushd "${TF_ENV_DIR}" >/dev/null
  terraform apply -input=false -auto-approve \
    -var="serving_image_tag=${IMAGE_TAG}"
  SERVING_URL="$(terraform output -raw serving_url)"
  CA_NAME="$(terraform output -raw serving_container_app_name)"
  popd >/dev/null
else
  pushd "${TF_ENV_DIR}" >/dev/null
  SERVING_URL="$(terraform output -raw serving_url)"
  CA_NAME="$(terraform output -raw serving_container_app_name)"
  popd >/dev/null
  echo "Updating Container App image to ${IMAGE}..."
  az containerapp update \
    --name "${CA_NAME}" \
    --resource-group "${RG}" \
    --image "${IMAGE}"
fi

echo "Waiting for revision to become Ready..."
for _ in $(seq 1 36); do
  STATE="$(az containerapp revision list \
    --name "${CA_NAME}" \
    --resource-group "${RG}" \
    --query "[?properties.trafficWeight > \`0\`].properties.runningState | [0]" \
    -o tsv 2>/dev/null || true)"
  if [[ "${STATE}" == "Running" ]]; then
    break
  fi
  sleep 5
done

echo "Smoke GET /health"
python3 - <<PY
import json, ssl, urllib.error, urllib.request, time

url = "${SERVING_URL}/health"
ctx = ssl.create_default_context()
last = None
for i in range(24):
    try:
        data = urllib.request.urlopen(url, context=ctx, timeout=30).read()
        print(json.dumps(json.loads(data), indent=2))
        raise SystemExit(0)
    except Exception as exc:
        last = exc
        time.sleep(5)
print("health failed:", last)
raise SystemExit(1)
PY

if [[ "${SKIP_ASK}" == "1" ]]; then
  echo "Skipping POST /api/ask (SKIP_ASK=1)"
else
  echo "Smoke POST /api/ask (short)"
  python3 - <<PY
import json, ssl, urllib.request

url = "${SERVING_URL}/api/ask"
body = json.dumps({"question": "What is the current ASB/MCSB version?"}).encode()
req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method="POST")
ctx = ssl.create_default_context()
try:
    raw = urllib.request.urlopen(req, context=ctx, timeout=180).read()
except Exception:
    raw = urllib.request.urlopen(req, context=ssl._create_unverified_context(), timeout=180).read()
payload = json.loads(raw)
print(json.dumps({
    "status": payload.get("status"),
    "session_id": payload.get("session_id"),
    "tool_path": payload.get("tool_path"),
    "pepper_configured": payload.get("pepper_configured"),
    "trace_id": payload.get("trace_id"),
    "answer_preview": (payload.get("answer") or "")[:400],
}, indent=2))
PY
fi

echo "Smoke GET / (UI)"
CODE="$(curl -sS -o /dev/null -w '%{http_code}' "${SERVING_URL}/")"
echo "UI HTTP ${CODE}"
[[ "${CODE}" == "200" ]]

echo "Serving URL: ${SERVING_URL}"
echo "Done."
