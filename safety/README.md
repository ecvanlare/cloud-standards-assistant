# Safety

Content Safety (Foundry RAI filters), instruction-level XPIA / citation / PII guards, and red-team notes for the Cloud Standards Assistant (AZP-1).

| Doc / script | Purpose |
|--------------|---------|
| [`content-safety.md`](content-safety.md) | RAI policy `csa-blocking-medium`, apply steps, blocked-prompt proof |
| [`scripts/apply-rai-policy.sh`](scripts/apply-rai-policy.sh) | Upsert policy + attach to `gpt-5-mini` deployment |
| [`RED-TEAM.md`](RED-TEAM.md) | Injection / citation / leak / PII / filter outcomes |
| [`../agents/instructions.md`](../agents/instructions.md) | Cite-or-defer, XPIA, PII, tool-path routing |
| [`../docs/COST-PER-INTERACTION.md`](../docs/COST-PER-INTERACTION.md) | Cost before/after tool-path tiering |

## Re-apply after account recreate

```bash
./safety/scripts/apply-rai-policy.sh
./agents/scripts/deploy-agent.sh   # wires rai_config ARM ID + current instructions
```

## Scope

- Uses account **RAI / content filters**, not a separate Azure AI Content Safety resource.
- No second chat model; “tiering” is Function vs Search routing (see cost doc).
