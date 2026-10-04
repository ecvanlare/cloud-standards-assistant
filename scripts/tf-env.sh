#!/usr/bin/env bash
# Terraform outputs for one environment as environment variables.
#
#   source scripts/tf-env.sh dev          # export into the current shell
#   scripts/tf-env.sh dev >> "$GITHUB_ENV" # GitHub Actions
#
# Requires an initialised terraform/envs/<env> (see `make init`).

tf_env_lines() {
  local env="${1:-${ENV:-dev}}"
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  terraform -chdir="${root}/terraform/envs/${env}" output -json | jq -r --arg env "${env}" '
    def o(k): .[k].value;
    {
      ENVIRONMENT: $env,
      FOUNDRY_ENDPOINT: o("foundry_endpoint"),
      FOUNDRY_PROJECT_ENDPOINT: o("foundry_project_endpoint"),
      CHAT_DEPLOYMENT: o("chat_deployment_name"),
      AGENT_DEPLOYMENT: o("agent_deployment_name"),
      EMBEDDING_DEPLOYMENT: o("embedding_deployment_name"),
      RAI_POLICY_ID: o("rai_policy_id"),
      SEARCH_ENDPOINT: o("search_endpoint"),
      SEARCH_CONNECTION_NAME: o("search_connection_name"),
      STORAGE_CONNECTION_NAME: o("storage_connection_name"),
      STORAGE_ACCOUNT_NAME: o("storage_account_name"),
      STORAGE_ACCOUNT_ID: o("storage_account_id"),
      CORPUS_CONTAINER: o("corpus_container_name"),
      FUNCTION_APP_NAME: o("function_app_name"),
      FUNCTION_BASE_URL: o("function_base_url"),
      REGISTRY_FUNCTION_APP_NAME: o("registry_function_app_name"),
      REGISTRY_FUNCTION_BASE_URL: o("registry_function_base_url"),
      SERVING_URL: o("serving_url")
    }
    | to_entries[]
    | select(.value != null)
    | "\(.key)=\(.value)"'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  tf_env_lines "$@"
else
  _tf_env_out="$(tf_env_lines "$@")" || return 1
  while IFS='=' read -r _tf_key _tf_value; do
    export "${_tf_key}=${_tf_value}"
  done <<<"${_tf_env_out}"
  unset _tf_env_out _tf_key _tf_value
fi
