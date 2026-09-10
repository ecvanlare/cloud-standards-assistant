#!/usr/bin/env bash
# Apply and deploy the env stack.
# Prereqs: az login, terraform.tfvars, remote state.
#
#   ./scripts/dev-up.sh
#   SKIP_SEARCH=1 ./scripts/dev-up.sh
#   SKIP_SERVING=1 ./scripts/dev-up.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV="${ENV:-dev}"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/${ENV}}"

SKIP_SEARCH="${SKIP_SEARCH:-0}"
SKIP_AGENT="${SKIP_AGENT:-0}"
SKIP_SERVING="${SKIP_SERVING:-0}"
SKIP_RAI="${SKIP_RAI:-1}"
SKIP_SMOKE="${SKIP_SMOKE:-0}"

command -v az >/dev/null
command -v terraform >/dev/null
export TF_ENV_DIR

if [[ "${SKIP_SERVING}" == "1" ]]; then
  echo "==> Terraform apply (${ENV}) — no serving image path"
  pushd "${TF_ENV_DIR}" >/dev/null
  terraform init -input=false >/dev/null
  terraform apply -input=false -auto-approve
  popd >/dev/null
else
  # ACR → build image → full apply (Container App needs an image before first create).
  # Skip /api/ask here; agent may not be registered yet.
  echo "==> Terraform + ACR image + Container App (${ENV})"
  SKIP_ASK=1 "${ROOT}/serving/scripts/deploy-serving.sh"
fi

echo "==> Function Apps"
"${ROOT}/tools/scripts/deploy-function.sh"
"${ROOT}/tools/scripts/deploy-registry-function.sh"

if [[ "${SKIP_SEARCH}" != "1" ]]; then
  echo "==> Search corpus + index"
  "${ROOT}/search/scripts/fetch-corpus.sh"
  "${ROOT}/search/scripts/upload-corpus.sh"
  "${ROOT}/search/scripts/deploy-search.sh"
  "${ROOT}/search/scripts/run-indexers.sh" || true
fi

if [[ "${SKIP_AGENT}" != "1" ]]; then
  echo "==> Foundry agent"
  "${ROOT}/agents/scripts/deploy-agent.sh"
fi

if [[ "${SKIP_RAI}" != "1" ]]; then
  echo "==> RAI policy"
  "${ROOT}/safety/scripts/apply-rai-policy.sh" || true
fi

if [[ "${SKIP_SMOKE}" != "1" && "${SKIP_AGENT}" != "1" ]]; then
  echo "==> Smoke demo"
  "${ROOT}/agents/scripts/run-demo.sh" \
    "What is the current Azure Security Benchmark version?" || true
fi

if [[ "${SKIP_SERVING}" != "1" ]]; then
  echo "UI: $(cd "${TF_ENV_DIR}" && terraform output -raw serving_url)"
fi
echo "Done. Tear down with: CONFIRM_DESTROY=1 ./scripts/dev-down.sh"
