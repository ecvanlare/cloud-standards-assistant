# Agents

The Foundry Agent Service definition for the Standards Assistant.

| File | Role |
|---|---|
| `standards-assistant.json` | Agent name, Search grounding (`corpus-tuned`, hybrid, top 5), OpenAPI tool references |
| `instructions.md` | When to use Search, a Function, or defer; citation, injection and PII rules |
| `scripts/deploy_agent.py` | Publishes a new agent version with the Search tool, both OpenAPI tools and the RAI policy |
| `scripts/run_demo.py` | Asks one question and prints the tool steps (`make demo`) |

Both scripts read their settings from `scripts/tf-env.sh`. The deploy workflow publishes a version on every deploy. See [Operations](../docs/OPERATIONS.md).
