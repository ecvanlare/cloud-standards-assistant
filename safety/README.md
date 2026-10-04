# Safety

Responsible AI controls for the Standards Assistant.

| Control | Where |
|---|---|
| RAI policy `csa-blocking-medium`: Hate, Sexual, Violence, Self-harm blocked at Medium on prompt and completion; Jailbreak on prompt; Protected Material on completion | `terraform/modules/foundry` (`azapi_resource.rai_policy`), attached to the agent and judge deployments |
| Agent `rai_config` set to the policy's resource ID (Agent Service rejects the short name) | `agents/scripts/deploy_agent.py` |
| Cite-or-defer, cross-prompt injection and PII instructions | `agents/instructions.md` |

Filters run on the Foundry account; there's no separate Content Safety resource. Red-team results are in [Evidence](../docs/EVIDENCE.md#red-team). Changes to the policy go through a pull request and a Terraform plan.
