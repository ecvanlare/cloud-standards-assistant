# Tool failure handling

## What we do

| Failure | Behaviour |
|---------|-----------|
| Azure Function 5xx / timeout | Function returns JSON `{ "error": ... }` or the platform times out. Agent instructions: say the tool failed; **do not invent** ASB version. One retry is allowed if the user still needs the live value. |
| Forced demo failure | `GET /api/asb/version?fail=true` returns **503** for Playground demos. |
| Slow Function | `?sleep_ms=N` (capped) simulates latency; agent should still surface failure if the call times out. |
| Terraform Registry 4xx/5xx / network error | OpenAPI tool surfaces the HTTP error. Agent reports Registry unavailable; does not invent provider versions. |
| Search empty / error | Existing cite-or-defer path: do not invent control text. |

## Retries

- **Function host:** Consumption plan may cold-start; a single automatic retry from the agent is acceptable for transient failures.
- **Agent policy:** at most one retry on tool failure for the same question; then tell the user the live lookup failed and offer corpus Search if relevant.
- **No silent fallback to training data** for version numbers.

## How to demo

```bash
# Healthy
curl -sS "$(cd terraform/envs/dev && terraform output -raw function_base_url)/asb/version"

# Forced error for agent failure path
curl -sS "$(cd terraform/envs/dev && terraform output -raw function_base_url)/asb/version?fail=true"
```

In Foundry Playground, ask for the current ASB version after enabling `fail=true` only if you temporarily point the OpenAPI server at a failing endpoint, or ask a Registry question while offline — then confirm the agent admits failure instead of guessing.
