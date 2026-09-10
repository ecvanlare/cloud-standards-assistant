#!/usr/bin/env bash
# Concurrent /health load against the serving Container App; print replica counts.
# Capture portal Metrics or this script's output as evidence (see serving/EVIDENCE.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/dev}"
CONCURRENCY="${CONCURRENCY:-40}"
REQUESTS="${REQUESTS:-200}"
DURATION_HINT="${DURATION_HINT:-60}"

command -v az >/dev/null
command -v python3 >/dev/null
command -v terraform >/dev/null

pushd "${TF_ENV_DIR}" >/dev/null
SERVING_URL="$(terraform output -raw serving_url)"
CA_NAME="$(terraform output -raw serving_container_app_name)"
RG="$(terraform output -raw resource_group_name)"
popd >/dev/null

echo "Target: ${SERVING_URL}"
echo "Before load — replica summary:"
az containerapp replica list \
  --name "${CA_NAME}" \
  --resource-group "${RG}" \
  -o table || true

echo "Firing ${REQUESTS} GETs /health with concurrency ${CONCURRENCY}..."
python3 - <<PY
import concurrent.futures
import ssl
import time
import urllib.error
import urllib.request

url = "${SERVING_URL}/health"
n = ${REQUESTS}
workers = ${CONCURRENCY}
ctx = ssl.create_default_context()

def one(_):
    t0 = time.time()
    try:
        with urllib.request.urlopen(url, context=ctx, timeout=60) as resp:
            code = resp.status
    except Exception as exc:
        return ("err", str(exc)[:80], time.time() - t0)
    return (code, "ok", time.time() - t0)

t0 = time.time()
ok = err = 0
lat = []
with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
    for code, msg, dt in pool.map(one, range(n)):
        lat.append(dt)
        if code == 200:
            ok += 1
        else:
            err += 1
elapsed = time.time() - t0
lat.sort()
p95 = lat[int(0.95 * (len(lat) - 1))] if lat else 0
print(f"done ok={ok} err={err} wall_s={elapsed:.1f} p95_s={p95:.2f}")
PY

echo "Waiting ${DURATION_HINT}s for scale metrics to settle..."
sleep "${DURATION_HINT}"

echo "After load — replica summary:"
az containerapp replica list \
  --name "${CA_NAME}" \
  --resource-group "${RG}" \
  -o table || true

echo "Scale rule (from app):"
az containerapp show \
  --name "${CA_NAME}" \
  --resource-group "${RG}" \
  --query "properties.template.scale" \
  -o json

echo "Capture Azure Portal → Container App → Metrics (Replica Count / Requests) for serving/EVIDENCE.md"
