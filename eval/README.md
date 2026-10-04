# Eval

The golden set and Foundry cloud evaluation for the Standards Assistant.

| File | Role |
|---|---|
| `golden_set.jsonl` | 65 questions with corpus-based `ground_truth` |
| `thresholds.json` | Minimum pass rates for the deploy gate |
| `results/history.csv` | Every scored run and whether the change was kept |
| `scripts/validate-golden-set.py` | Schema check, run in CI |
| `scripts/export-foundry-dataset.py` | Golden set to Foundry JSONL (drops out-of-scope rows) |
| `scripts/run-foundry-eval.py` | Uploads the dataset and runs the cloud eval against the agent; `--gate` fails on thresholds |

Run with `make eval` (8 rows, gated) or `make eval-full`. See [Operations](../docs/OPERATIONS.md#evaluate).

## Ground truth rules

Each row has `id`, `question`, `ground_truth`, `source`, `category` (`well-architected`, `asb`, `nist`, `terraform`, `cross-source`, `out-of-scope`) and `difficulty`.

- Copy or tightly paraphrase text from fetched corpus files. Never write it from memory.
- Use the Azure Security Benchmark (MCSB), not CIS. Map other frameworks only where ASB pages state the mapping.
- Leave `PLACEHOLDER` rows empty until the cited chunks exist.
- Out-of-scope rows (pricing, live inventory) expect a deferral, never a number.
- NIST rows stick to what `corpus/nist/` actually contains.
