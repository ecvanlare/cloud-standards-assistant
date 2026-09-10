#!/usr/bin/env bash
# Tear down the Azure env stack to stop idle spend (Search / Foundry / ACA / Functions / …).
# Keeps Terraform remote state (rg-csa-tfstate-uks) unless you delete that separately.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV="${ENV:-dev}"
TF_ENV_DIR="${TF_ENV_DIR:-${ROOT}/terraform/envs/${ENV}}"

command -v terraform >/dev/null

if [[ "${CONFIRM_DESTROY:-}" != "1" ]]; then
  echo "This will terraform destroy ${TF_ENV_DIR}."
  echo "Re-run with CONFIRM_DESTROY=1 to proceed (keeps remote state)."
  exit 1
fi

pushd "${TF_ENV_DIR}" >/dev/null
terraform init -input=false >/dev/null
terraform destroy -input=false -auto-approve
popd >/dev/null

echo "Destroyed ${ENV}. Remote state remains. Bring back with: ./scripts/dev-up.sh"
