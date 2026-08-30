# Terraform

Parameterized modules + three environment roots for the Cloud Standards Assistant.

## Layout

- `modules/` — resource modules (dumb: take `name` + `tags`)
- `envs/{dev,staging,prod}/` — root modules; naming via `locals.tf`
- `bootstrap/` — one-shot remote state script

## Naming

Short convention — workload `csa`, region short `uks`. See [docs/INFRASTRUCTURE.md](../docs/INFRASTRUCTURE.md).

## Prerequisites

```bash
az login
az account set --subscription <subscription-id>
SUBSCRIPTION_ID=<subscription-id> ./terraform/bootstrap/bootstrap-state.sh
# Set a subscription budget alert in the portal before apply
```

Subscription IDs belong in local `terraform.tfvars` / env vars only — not in committed code.

## Apply (dev only for Phase 1)

```bash
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars   # then set subscription_id
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Staging/prod use the same modules with different `terraform.tfvars` / backend containers — do not apply until needed.

## Remote state backend

Created by `bootstrap/bootstrap-state.sh`:

- RG: `rg-csa-tfstate-uks`
- SA: `stcsatfstateuks`
- Containers: `tfstate-dev|staging|prod`
