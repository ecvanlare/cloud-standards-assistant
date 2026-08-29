# Terraform

- `modules/` — reusable modules (resource group, VNet, Foundry project, AI Search, storage, Key Vault, Container Apps env, AKS (unused by default, see ADR-0001))
- `envs/{dev,staging,prod}/` — one root module per environment, wiring the shared modules together with env-specific tfvars

## Remote state backend (bootstrap once, outside these envs)

```bash
az group create -n tfstate-rg -l uksouth
az storage account create -n <globally-unique-name> -g tfstate-rg -l uksouth --sku Standard_LRS
az storage container create -n tfstate --account-name <globally-unique-name>
```

Then reference it in each env's backend block.
