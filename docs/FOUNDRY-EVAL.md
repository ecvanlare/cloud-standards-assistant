# Foundry cloud Evaluation

Portal-visible evaluation path for the Cloud Standards Assistant. Repo eval (`eval/scripts/run_eval.py`) stays the CI/local source of truth; this path uploads a dataset and runs scored agent evaluations so they appear under the Foundry **Evaluations** tab.

## Prerequisites

1. **Terraform identity** — project managed identity has **Storage Blob Data Contributor** on the corpus storage account (`stcsa…`). Applied via `terraform/modules/identity` (`foundry_project_storage_blob_data_contributor`).
2. **Project storage connection (Entra)** — Azure Storage Account connection on the Foundry project (`csa-corpus-storage` by default).

### Portal clicks (if you prefer UI)

1. Open Microsoft Foundry → project `proj-csa-dev` (or your env project).
2. **Manage** → **Project details** → **Connected resources** → **Add connection**.
3. Choose **Azure Storage**, pick the corpus account from Terraform (`storage_account_name` output).
4. Authentication: **Microsoft Entra ID** (not account key).
5. Confirm Evaluations / Datasets no longer error with “missing storage”.

### Script (preferred)

```bash
./eval/scripts/ensure-storage-connection.sh
```

Uses the same management-plane pattern as `agents/scripts/ensure-search-connection.sh` (`category: AzureStorageAccount`, `authType: AAD` — Entra ID).

## Smoke run (5–10 rows)

From the regression wrapper (schema first, then cloud):

```bash
EVAL_LIMIT=8 RUN_FOUNDRY_CLOUD_EVAL=1 ./eval/scripts/run-regression.sh
```

Or call the cloud script directly:

```bash
# Azure login + terraform state for terraform/envs/dev
./eval/scripts/run-foundry-eval.sh
# or: EVAL_LIMIT=5 ./eval/scripts/run-foundry-eval.sh
```

What it does:

1. Upserts the storage connection
2. Exports `eval/golden_set.jsonl` → `eval/results/foundry-dataset.jsonl` (`query` = `question`; drops `out-of-scope` by default)
3. Uploads a versioned dataset via `AIProjectClient.datasets.upload_file`
4. Creates an eval (coherence + relevance builtins) and a run targeting agent `cloud-devops-standards-assistant` (version from `agents/.last-deploy.json` when present)
5. Polls until complete; writes `eval/results/foundry-eval-latest.json` (includes `report_url` when the API returns one)

Dataset upload uses `AIProjectClient`. Eval create / run / poll use the project **OpenAI-compatible REST** path (`…/openai/v1/evals`) via `httpx`, because the `openai` Python SDK’s TypedDict transform crashes on Python 3.9 (`NameError: Input is not defined`). Same Foundry API either way.

Manual pieces:

```bash
export FOUNDRY_PROJECT_ENDPOINT="$(cd terraform/envs/dev && terraform output -raw foundry_project_endpoint)"
export CHAT_DEPLOYMENT="$(cd terraform/envs/dev && terraform output -raw chat_deployment_name)"

python3 eval/scripts/export-foundry-dataset.py --limit 8
python3 eval/scripts/upload-foundry-dataset.py --file eval/results/foundry-dataset.jsonl
python3 eval/scripts/run-foundry-eval.py --dataset-id '<id-from-upload>' --skip-upload
```

## Full golden set

Omit `--limit` / set `EVAL_LIMIT` high. **Cost warning:** each row invokes the agent (Search + tools) plus judge-model tokens for every testing criterion. Sixty-five rows is many agent + judge calls — run smoke first.

```bash
EVAL_LIMIT=65 ./eval/scripts/run-foundry-eval.sh
```

## Out-of-scope rows

Rows with `category: out-of-scope` (or `ground_truth` starting with `OUT OF SCOPE`) are **excluded** by default so quality judges are not failed for intentional deferrals. Pass `--include-out-of-scope` on export if you need them tagged (`defer: true`) for a separate run.

## Region / evaluator notes (UK South)

- Start with **coherence** + **relevance** (`builtin.*`) and `gpt-5-mini` as judge (`CHAT_DEPLOYMENT`).
- Safety builtins (e.g. `builtin.violence`) may be unavailable or constrained by region; use `run-foundry-eval.py --with-safety` only after smoke succeeds.
- Mapping `ground_truth` into relevance is best-effort; groundedness-style judges are optional follow-ups if your project supports them.

## Dual path

| Path | When | Where scores live |
|------|------|-------------------|
| Repo eval (`run_eval.py` / `run-regression.sh`) | CI schema + local regression | `eval/results/` |
| Foundry cloud eval (this doc) | Portal demos, shareable runs | Foundry **Evaluations** tab |

Do not replace the GitHub Actions schema gate with live Foundry eval until OIDC is wired.
