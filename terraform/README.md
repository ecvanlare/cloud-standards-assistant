# Terraform

All Azure resources for the Standards Assistant, including the Foundry connections and the RAI policy.

| Path | Role |
|---|---|
| `modules/` | One module per component, taking names and tags |
| `envs/{dev,staging,prod}/` | Environment roots; names in `locals.tf`, per-environment defaults in `variables.tf` |
| `bootstrap/bootstrap-state.sh` | Remote state storage, plus your blob role on it |
| `bootstrap/github-oidc/` | One deploy identity per GitHub Environment, with federated credentials and constrained roles |

Providers: `azurerm` and `azapi` (Terraform 1.11 or later). State uses Entra auth (`use_azuread_auth`). The deploy workflow applies the environment roots; locally, use `make init` and `make plan`. Real `terraform.tfvars` files stay untracked. See [Operations](../docs/OPERATIONS.md#first-time-setup).
