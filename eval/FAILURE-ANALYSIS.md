# Eval failure analysis (AZP-8)

## Run context (smoke, 2026-09-09)

- Agent: `cloud-devops-standards-assistant:9`
- Rows scored: `AZP-EVAL-001`, `AZP-EVAL-002`, `AZP-EVAL-005` via `eval/scripts/run_eval.py`
- Judge mode: Foundry chat deployment (`foundry_chat_judge`) — Entra ID. Set `FOUNDRY_JUDGE_API_KEY` to use package `GroundednessEvaluator` / `RelevanceEvaluator` / `ContentSafetyEvaluator` instead.
- Metrics (`eval/results/latest-summary.md`): groundedness.avg ≈ **3.33**, relevance.avg ≈ **3.67**, safety.safe_rate **1.0**

## Observations from smoke answers

| ID | Pattern | Why |
|----|---------|-----|
| AZP-EVAL-001 (WAF pillars) | Often high relevance; groundedness varies if answer expands beyond GT list | Agent may add commentary; GT is the five pillar names |
| AZP-EVAL-002 (storage public network) | Needs Search/ASB retrieval | Failures = retrieval miss or paraphrase drift vs baseline wording |
| AZP-EVAL-005 (pricing OOS) | Success = defer | If model invents a price, treat as hard regression fail |

## How to interpret failures

| Pattern | Likely cause | Mitigation |
|---------|--------------|------------|
| Low groundedness, high relevance | Fluent answer not tied to GT/context | Prefer citations; tighten instructions |
| Low relevance | Wrong tool / acronym ambiguity | Clearer prompts; pin agent version |
| Safety unsafe | Rare on standards Q&A | Review Content Safety / jailbreak rows |
| Empty / “I'll check…” | No tool call | Retry; explicit operation wording |
| OOS answered with a number | Training-data leak | Hard fail |

## Category notes

- **well-architected / asb / terraform:** Search-backed; watch synthesis drift.
- **cross-source:** Must cover ASB and WAF angles.
- **nist:** Keep narrow — corpus fetch is thin.
- **out-of-scope:** Defer/flag only.

Re-run full set with `python3 eval/scripts/run_eval.py` (no `--limit`) before claiming production readiness; update metrics here.
