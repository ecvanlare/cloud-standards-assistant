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

## Two eval paths

| Path | Purpose | Entry |
|------|---------|--------|
| **Repo eval** | CI/local source of truth; schema gate + laptop scoring | `validate-golden-set.py`, `run_eval.py`, `run-regression.sh` |
| **Foundry cloud eval** | Portal-visible runs under **Evaluations** | `run-foundry-eval.sh` — see [`docs/FOUNDRY-EVAL.md`](../docs/FOUNDRY-EVAL.md) |

Keep both. Cloud eval does not replace the schema CI check.

## Scripts

```bash
# Schema / category / ID checks (≥50 rows)
python3 eval/scripts/validate-golden-set.py

# Repo path: agent answers + local/Foundry-chat judge (needs Azure login + TF outputs)
export FOUNDRY_PROJECT_ENDPOINT="$(cd terraform/envs/dev && terraform output -raw foundry_project_endpoint)"
export FOUNDRY_ENDPOINT="$(cd terraform/envs/dev && terraform output -raw foundry_endpoint)"
export CHAT_DEPLOYMENT="$(cd terraform/envs/dev && terraform output -raw chat_deployment_name)"
python3 eval/scripts/run_eval.py --limit 5   # smoke
# Full set: omit --limit (slow / token cost)

# CI-friendly wrapper (schema always; optional live / cloud)
./eval/scripts/run-regression.sh
RUN_LIVE_EVAL=1 ./eval/scripts/run-regression.sh                    # repo scores
EVAL_LIMIT=8 RUN_FOUNDRY_CLOUD_EVAL=1 ./eval/scripts/run-regression.sh  # portal Evaluations
# Both: RUN_LIVE_EVAL=1 RUN_FOUNDRY_CLOUD_EVAL=1 EVAL_LIMIT=5 ./eval/scripts/run-regression.sh

# Foundry cloud path directly (same as the cloud flag above)
./eval/scripts/ensure-storage-connection.sh
EVAL_LIMIT=8 ./eval/scripts/run-foundry-eval.sh
```

Results land under `eval/results/` (gitignored except `latest-summary.md`). Cloud summary: `foundry-eval-latest.json`. See [`FAILURE-ANALYSIS.md`](FAILURE-ANALYSIS.md) and [`docs/FOUNDRY-EVAL.md`](../docs/FOUNDRY-EVAL.md).

Populate or refresh corpus first:

```bash
./search/scripts/fetch-corpus.sh
```
