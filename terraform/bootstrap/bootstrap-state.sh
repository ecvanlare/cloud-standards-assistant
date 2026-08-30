#!/usr/bin/env bash
# One-time bootstrap: remote Terraform state storage.
# Prerequisites: az CLI authenticated to the target subscription.
#
# Usage:
#   SUBSCRIPTION_ID=<your-subscription-id> ./terraform/bootstrap/bootstrap-state.sh

set -euo pipefail

if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
  echo "ERROR: SUBSCRIPTION_ID is required." >&2
  echo "Usage: SUBSCRIPTION_ID=<your-subscription-id> $0" >&2
  exit 1
fi

LOCATION="${LOCATION:-uksouth}"
RG_NAME="${RG_NAME:-rg-csa-tfstate-uks}"
# Storage account names: 3-24 lowercase alphanumeric, globally unique.
SA_NAME="${SA_NAME:-stcsatfstateuks}"

az account set --subscription "$SUBSCRIPTION_ID"
az group create --name "$RG_NAME" --location "$LOCATION" --tags workload=csa managed_by=terraform project=cloud-standards-assistant purpose=tfstate

if ! az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" &>/dev/null; then
  az storage account create \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags workload=csa managed_by=terraform project=cloud-standards-assistant purpose=tfstate
fi

for c in tfstate-dev tfstate-staging tfstate-prod; do
  az storage container create --name "$c" --account-name "$SA_NAME" --auth-mode login >/dev/null || \
    az storage container create --name "$c" --account-name "$SA_NAME"
done

echo "Remote state ready:"
echo "  resource_group  = $RG_NAME"
echo "  storage_account = $SA_NAME"
echo "  containers      = tfstate-dev, tfstate-staging, tfstate-prod"
echo
echo "Set a budget alert in the portal (Cost Management) before first terraform apply."
