#!/usr/bin/env bash
# Repo-local Python env for deploy/eval scripts. Source, then call use_repo_python.
# Homebrew and distro Pythons refuse global/--user pip installs (PEP 668), so
# everything runs from ${ROOT}/.venv with pinned scripts/requirements.txt.

use_repo_python() {
  local root venv base
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  venv="${root}/.venv"
  base="${PYTHON_BASE:-python3}"

  if [[ ! -x "${venv}/bin/python" ]]; then
    command -v "${base}" >/dev/null 2>&1 || {
      echo "Missing ${base}; install Python 3.10+ or set PYTHON_BASE." >&2
      exit 1
    }
    echo "Creating ${venv}"
    "${base}" -m venv "${venv}"
  fi

  "${venv}/bin/python" -m pip install --quiet --disable-pip-version-check \
    -r "${root}/scripts/requirements.txt"

  export PATH="${venv}/bin:${PATH}"
  export PYTHON_BIN="${venv}/bin/python"
}
