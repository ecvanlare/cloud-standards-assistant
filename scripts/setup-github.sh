#!/usr/bin/env bash
# One-time GitHub setup after `terraform apply` in terraform/bootstrap/github-oidc:
# squash-only merges, protected main, environments with approval gates, deploy secrets.
#
#   scripts/setup-github.sh
#
# Secrets are environment-scoped, piped to gh on stdin, and never printed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="${ROOT}/terraform/bootstrap/github-oidc"
ENVIRONMENTS=(dev staging prod)
REQUIRED_CHECKS='["lint","terraform","serving-image"]'

for cmd in gh az jq terraform; do
  command -v "${cmd}" >/dev/null || { echo "Missing required command: ${cmd}" >&2; exit 1; }
done

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
outputs="$(terraform -chdir="${BOOTSTRAP_DIR}" output -json)"
reviewer_id="$(gh api user -q .id)"
subscription_id="$(az account show --query id -o tsv)"
operator_ids="$(az ad signed-in-user show --query id -o tsv | jq -Rc '[.]')"

echo "${repo}: squash-only merges, delete branch on merge"
gh api -X PATCH "repos/${repo}" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY >/dev/null

echo "${repo}: protect main"
jq -n --argjson checks "${REQUIRED_CHECKS}" '{
  required_status_checks: {strict: true, contexts: $checks},
  enforce_admins: false,
  required_pull_request_reviews: {required_approving_review_count: 0},
  restrictions: null,
  required_linear_history: true,
  allow_force_pushes: false,
  allow_deletions: false
}' | gh api -X PUT "repos/${repo}/branches/main/protection" --input - >/dev/null

for env in "${ENVIRONMENTS[@]}"; do
  echo "Environment ${env}"
  if [[ "${env}" == "dev" ]]; then
    body='{}'
  else
    body="$(jq -n --argjson id "${reviewer_id}" '{
      reviewers: [{type: "User", id: $id}],
      deployment_branch_policy: {protected_branches: true, custom_branch_policies: false}
    }')"
  fi
  gh api -X PUT "repos/${repo}/environments/${env}" --input - <<<"${body}" >/dev/null
  jq -r --arg env "${env}" '.client_ids.value[$env]' <<<"${outputs}" \
    | gh secret set AZURE_CLIENT_ID --repo "${repo}" --env "${env}"
  jq -r '.tenant_id.value' <<<"${outputs}" | gh secret set AZURE_TENANT_ID --repo "${repo}" --env "${env}"
  gh secret set AZURE_SUBSCRIPTION_ID --repo "${repo}" --env "${env}" <<<"${subscription_id}"
  gh secret set OPERATOR_OBJECT_IDS --repo "${repo}" --env "${env}" <<<"${operator_ids}"
done

gh variable set AZURE_OIDC_CONFIGURED --repo "${repo}" --body true

echo "Done."
