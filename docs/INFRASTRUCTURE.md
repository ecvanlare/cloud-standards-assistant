# Infrastructure

> Fill in as Phase 1 lands.

## Resources provisioned by Terraform

- Resource group
- Virtual network
- Microsoft Foundry project
- Azure AI Search
- Storage account (corpus + Terraform remote state)
- Key Vault
- Container Apps environment (see [ADR-0001](adr/0001-compute-platform.md))
- Model deployments from the Foundry catalog
- Managed identities for service-to-service auth

## Remote state

Terraform state lives in an Azure Storage backend. Bootstrap steps and the exact storage account/container names go here once created.

## Environments

| Environment | Purpose | Notes |
|---|---|---|
| dev | Iteration | Lower-tier SKUs, torn down freely |
| staging | Pre-prod validation | Mirrors prod topology at smaller scale |
| prod | The demo-facing deployment | Budget alert required before first apply |

## Cost estimate

> Fill in once resources are sized — target: keep this cheap to leave running. Container Apps + AI Search Basic/Standard + a small Foundry model deployment should be low double-digit USD/month if not left maxed out. Set a budget alert (see Common Pitfalls in the brief) before the first `terraform apply`.

## Teardown

```bash
cd terraform/envs/<env>
terraform destroy
```
