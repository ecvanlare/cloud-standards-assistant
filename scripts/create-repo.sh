#!/usr/bin/env bash
# One-time setup: turns this local folder into a git repo and pushes it to
# a new GitHub repo.
#
# Prerequisites:
#   - gh CLI installed and authenticated: gh auth login
#   - Run from inside this folder
#
# Usage:
#   ./scripts/create-repo.sh <repo-name> [public|private]

set -euo pipefail

REPO_NAME="${1:-cloud-standards-assistant}"
VISIBILITY="${2:-public}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Git repo already initialized; skipping git init."
else
  git init
fi

git add .

if ! git rev-parse HEAD >/dev/null 2>&1; then
  git commit -m "Initial scaffold: repo structure, docs, CI skeleton, ADR-0001"
elif ! git diff --cached --quiet; then
  git commit -m "Initial scaffold: repo structure, docs, CI skeleton, ADR-0001"
else
  echo "Nothing new to commit."
fi

git branch -M main

if git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 'origin' already exists; pushing main..."
  git push -u origin main
else
  gh repo create "$REPO_NAME" --"$VISIBILITY" --source=. --remote=origin --push
fi

echo "Repo created and pushed. Now run:"
echo "  ./scripts/setup-branch-protection.sh"
