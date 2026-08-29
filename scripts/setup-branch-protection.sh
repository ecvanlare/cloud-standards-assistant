#!/usr/bin/env bash
# Sets branch protection rules on `main` for this repo, using the GitHub CLI.
#
# Prerequisites:
#   - gh CLI installed and authenticated: gh auth login
#   - Run from inside the repo (after `git remote add origin ...` and first push)
#
# Usage:
#   ./scripts/setup-branch-protection.sh
#
# Note: required status checks are omitted until Phase 1 lands real Terraform
# (empty env stubs would fail or never report CI and block merges).

set -euo pipefail

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Applying branch protection to $REPO on branch 'main'..."

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "repos/${REPO}/branches/main/protection" \
  --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
EOF

echo "Done. 'main' now requires a PR (no direct pushes), linear history, and blocks force-push/delete."
echo "Note: required_approving_review_count is set to 0 since this is a solo repo — GitHub won't let you approve your own PR anyway. Raise it if you add collaborators."
echo "Note: CI status checks are not required yet — re-add them in Phase 1 once Terraform validates cleanly."
