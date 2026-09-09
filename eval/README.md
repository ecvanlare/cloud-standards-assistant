# Eval

Golden questions for the Cloud Standards Assistant. Answers must come from the local corpus under `corpus/` — not from model memory.

## Schema

`golden_set.jsonl` is one JSON object per line:

| Field | Values |
| --- | --- |
| `id` | `AZP-EVAL-NNN` |
| `question` | Natural-language prompt |
| `ground_truth` | Expected answer (corpus paraphrase) or `OUT OF SCOPE - ...` |
| `source` | Corpus path(s), or `N/A` for out-of-scope |
| `category` | `well-architected` \| `asb` \| `nist` \| `terraform` \| `cross-source` \| `out-of-scope` |
| `difficulty` | `easy` \| `medium` \| `hard` |

## ASB, not CIS

This repo uses the **Azure Security Benchmark / Microsoft cloud security benchmark** (`corpus/asb/`). Do **not** invent or quote CIS Benchmark control text. CIS paths under `corpus/cis/` are unused. Map industry frameworks only when the ASB/MCSB pages themselves state the mapping.

## Ground truth rules

- Copy or tightly paraphrase text that appears in fetched corpus files.
- Leave `PLACEHOLDER` rows empty until the cited chunks exist (none in the current set).
- `out-of-scope` rows (pricing, live inventory) stay defer/flag — do not invent numbers or resource lists.
- NIST questions must stick to what `corpus/nist/csf-identify.md` actually says (the fetch is thin).

## Scripts

```bash
# Schema / category / ID checks (≥50 rows)
python3 eval/scripts/validate-golden-set.py

# Agent answers + Foundry evaluators (needs Azure login + TF outputs)
export FOUNDRY_PROJECT_ENDPOINT="$(cd terraform/envs/dev && terraform output -raw foundry_project_endpoint)"
export FOUNDRY_ENDPOINT="$(cd terraform/envs/dev && terraform output -raw foundry_endpoint)"
export CHAT_DEPLOYMENT="$(cd terraform/envs/dev && terraform output -raw chat_deployment_name)"
python3 eval/scripts/run_eval.py --limit 5   # smoke
# Full set: omit --limit (slow / token cost)

# CI-friendly wrapper (schema always; live when RUN_LIVE_EVAL=1)
./eval/scripts/run-regression.sh
```

Results land under `eval/results/` (gitignored except `latest-summary.md`). See [`FAILURE-ANALYSIS.md`](FAILURE-ANALYSIS.md).

Populate or refresh corpus first:

```bash
./search/scripts/fetch-corpus.sh
```
