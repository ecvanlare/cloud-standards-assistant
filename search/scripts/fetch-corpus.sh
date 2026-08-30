#!/usr/bin/env bash
# Download public corpus pages listed in search/corpus-manifest.json into ./corpus.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_common.sh"

require_cmd curl
require_cmd jq
require_cmd python3

mkdir -p "${CORPUS_DIR}"/{waf,asb,nist,terraform}

manifest="${SEARCH_DIR}/corpus-manifest.json"
count="$(jq '.documents | length' "${manifest}")"

for i in $(seq 0 $((count - 1))); do
  rel="$(jq -r ".documents[$i].relative_path" "${manifest}")"
  url="$(jq -r ".documents[$i].source_url" "${manifest}")"
  framework="$(jq -r ".documents[$i].framework" "${manifest}")"
  section="$(jq -r ".documents[$i].section" "${manifest}")"
  title="$(jq -r ".documents[$i].title" "${manifest}")"
  out="${CORPUS_DIR}/${rel}"
  mkdir -p "$(dirname "${out}")"
  echo "Fetching ${url} -> ${out}"
  tmp="$(mktemp)"
  if ! curl -fsSL -A "cloud-standards-assistant-corpus-fetch/1.0" -o "${tmp}" "${url}"; then
    echo "WARN: fetch failed for ${url}; leaving any existing file" >&2
    rm -f "${tmp}"
    continue
  fi
  python3 - "${tmp}" "${out}" "${url}" "${framework}" "${section}" "${title}" <<'PY'
import html
import re
import sys
from pathlib import Path

src, dest, url, framework, section, title = sys.argv[1:7]
raw = Path(src).read_text(encoding="utf-8", errors="ignore")
# Prefer main/article text; strip tags lightly for indexer-friendly markdown-ish text.
text = re.sub(r"(?is)<script.*?>.*?</script>", " ", raw)
text = re.sub(r"(?is)<style.*?>.*?</style>", " ", text)
text = re.sub(r"(?is)<nav.*?>.*?</nav>", " ", text)
text = re.sub(r"(?is)<footer.*?>.*?</footer>", " ", text)
text = re.sub(r"(?s)<[^>]+>", " ", text)
text = html.unescape(text)
text = re.sub(r"[ \t]+", " ", text)
text = re.sub(r"\n{3,}", "\n\n", text)
text = text.strip()
header = (
    f"Source-URL: {url}\n"
    f"Framework: {framework}\n"
    f"Section: {section}\n"
    f"Title: {title}\n\n"
)
Path(dest).write_text(header + text + "\n", encoding="utf-8")
PY
  rm -f "${tmp}"
done

echo "Done. Fetched documents are under ${CORPUS_DIR}/ (waf, asb, nist, terraform)."
