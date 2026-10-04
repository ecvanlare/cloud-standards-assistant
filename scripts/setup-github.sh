#!/usr/bin/env bash
# One-time GitHub setup: squash-only merges and a protected main.
#
#   scripts/setup-github.sh
set -euo pipefail

REQUIRED_CHECKS='["lint","terraform","serving-image"]'

for cmd in gh jq; do
  command -v "${cmd}" >/dev/null || { echo "Missing required command: ${cmd}" >&2; exit 1; }
done

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

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
  enforce_admins: true,
  required_pull_request_reviews: {required_approving_review_count: 0},
  restrictions: null,
  required_linear_history: true,
  allow_force_pushes: false,
  allow_deletions: false
}' | gh api -X PUT "repos/${repo}/branches/main/protection" --input - >/dev/null

echo "Done."
