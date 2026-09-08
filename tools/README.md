# Tools (AZP-3)

Three tools on the Cloud & DevOps Standards Assistant:

| Tool | Kind | When to use |
|------|------|-------------|
| Azure AI Search | Foundry Search tool → `corpus-tuned` | Standards guidance / citations |
| ASB version | Function App A (`GET /api/asb/version`) via OpenAPI | Current ASB/MCSB version/revision |
| Terraform Registry | Function App B (`GET /api/terraform/providers/...`) via OpenAPI | Live provider/module versions from `registry.terraform.io` |

Function B proxies HashiCorp because Foundry OpenAPI did not reliably invoke `registry.terraform.io` directly. Two Function Apps keep independent URLs and deploys. Container Apps stay reserved for Phase 7 serving.

## Layout

| Path | Role |
|------|------|
| `functions/asb_version/` | ASB version Function source |
| `functions/terraform_registry/` | Registry proxy Function source |
| `openapi/asb-version-function.json` | OpenAPI for ASB Function (`__FUNCTION_BASE_URL__`) |
| `openapi/terraform-registry.json` | OpenAPI for Registry Function (`__REGISTRY_FUNCTION_BASE_URL__`) |
| `scripts/deploy-function.sh` | Zip-deploy ASB Function |
| `scripts/deploy-registry-function.sh` | Zip-deploy Registry Function |
| `FAILURE-HANDLING.md` | Timeouts / errors / retries |
| `TRACE.md` | Example non-Search tool selection |

## Deploy (dev)

```bash
cd terraform/envs/dev && terraform apply
../../tools/scripts/deploy-function.sh
../../tools/scripts/deploy-registry-function.sh
../../agents/scripts/deploy-agent.sh
```

Local scripts vs what a pipeline would replace them with: [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md).
