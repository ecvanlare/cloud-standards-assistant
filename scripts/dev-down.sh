#!/usr/bin/env bash
# Remove env Azure resources and clear Terraform state for that env.
# Remote state storage is kept.
#
#   CONFIRM_DESTROY=1 ./scripts/dev-down.sh
#   MODE=terraform CONFIRM_DESTROY=1 ./scripts/dev-down.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV="${ENV:-dev}"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/${ENV}}"
MODE="${MODE:-group}"

command -v az >/dev/null
command -v terraform >/dev/null

if [[ "${CONFIRM_DESTROY:-}" != "1" ]]; then
  echo "Usage: CONFIRM_DESTROY=1 ./scripts/dev-down.sh"
  exit 1
fi

pushd "${TF_ENV_DIR}" >/dev/null
terraform init -input=false >/dev/null

RG=""
if RG="$(terraform output -raw resource_group_name 2>/dev/null)"; then
  :
else
  RG="rg-csa-${ENV}-uks"
fi

echo "Resource group: ${RG}"

if [[ "${MODE}" == "group" ]]; then
  if az group show --name "${RG}" &>/dev/null; then
    az group delete --name "${RG}" --yes
  fi
  terraform destroy -input=false -auto-approve -refresh=true || {
    while read -r addr; do
      [[ -z "${addr}" ]] && continue
      case "${addr}" in
        data.*) continue ;;
      esac
      terraform state rm "${addr}" 2>/dev/null || true
    done < <(terraform state list 2>/dev/null || true)
  }
else
  terraform destroy -input=false -auto-approve
fi

popd >/dev/null
echo "Done. Recreate with: ./scripts/dev-up.sh"
