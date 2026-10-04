# Operations

GitHub Actions deploys and changes every environment. The `Makefile` either starts those workflows or runs read-only and data-plane steps against an environment you're signed in to.

## First-time setup

| Step | Command | Notes |
|---|---|---|
| Remote state | `SUBSCRIPTION_ID=<subscription-id> terraform/bootstrap/bootstrap-state.sh` | Storage account `stcsatfstateuks`, one container per environment |
| Deploy identities | `terraform -chdir=terraform/bootstrap/github-oidc init -backend-config=backend.hcl && terraform -chdir=terraform/bootstrap/github-oidc apply` | Copy `terraform.tfvars.example` to `terraform.tfvars` first (untracked) |
| GitHub | `scripts/setup-github.sh` | Environments, approvals, secrets, squash-only merges, protected `main` |
| Budget | Cost Management, on the subscription | Not in code (see [Decisions](DECISIONS.md#known-well-architected-trade-offs)) |
| Local tools | `make venv`, then `make init ENV=dev` | Python venv; Terraform with Entra auth to state |

## Deploy and promote

| Trigger | What runs |
|---|---|
| Pull request | `ci.yml`: shellcheck, ruff, actionlint, golden-set schema, `terraform validate`, image build, dev plan (resource addresses only) |
| Merge to `main` | `deploy.yml` deploys dev |
| Deploy workflow, `target: staging` or `prod` | Dev, then each gated environment after a reviewer approves |

For each environment, [`deploy-env.yml`](../.github/workflows/deploy-env.yml) runs, in order:

1. Container registry (targeted apply).
2. Image: built in dev, imported from the previous environment in staging and prod.
3. Full `terraform apply` with the image tagged by commit SHA.
4. Both Functions (remote build).
5. Search corpus (`publish.sh all`).
6. A new agent version.
7. Smoke test.
8. Eval gate.

Deploys to the same environment queue rather than overlap.

The first deploy can fail at the corpus step while new data-plane roles propagate. Re-run the job.

## Evaluate

| Run | How | Gate |
|---|---|---|
| Smoke | `make smoke`, also in every deploy | Health, both Functions, UI, and one multi-tool answer with a `trace_id` |
| Eval gate | `make eval`, also in every deploy | 8 golden rows against [`eval/thresholds.json`](../eval/thresholds.json); exits 2 on a miss |
| Full | **Eval** workflow or `make eval-full` | None. 62 rows plus task adherence and intent resolution. Can take over an hour. |

To resume a timed-out run without paying for a new one, pass `--eval-id` and `--run-id` to `eval/scripts/run-foundry-eval.py`. Add rows to [`history.csv`](../eval/results/history.csv) when a change is kept or discarded.

Out-of-scope rows are excluded from cloud runs so that correct deferrals aren't scored as failures.

## Monitor

- **Request to agent:** take the `trace_id` from the UI and open it in App Insights transaction search. Open the Foundry traces for the same conversation.
- **Queries:** [`observability/queries.kql`](observability/queries.kql), including the backend's `csa_*` dimensions.
- **Tool failure drill:** `curl "$FUNCTION_BASE_URL/asb/version?fail=true"` returns 503. The agent should report the failure, not guess.

## Safety re-check

The RAI policy is applied with every deploy, so there's nothing to re-apply. To re-test, run the red-team prompts in [Evidence](EVIDENCE.md#red-team) with `make demo QUESTION="..."`. The cross-prompt injection prompt should be blocked with `content_filter` (jailbreak).

## Tear down

Run the **Teardown** workflow (or `make teardown ENV=dev CONFIRM=dev`). Type the environment name to confirm. It runs `terraform destroy`, then purges the soft-deleted Foundry account, so a redeploy doesn't bring back old agents. State and deploy identities are kept.

## Branches

Work on `<type>/AZP-<n>-<slug>` and open a pull request. `main` accepts squash merges only, so each PR lands as one commit.
