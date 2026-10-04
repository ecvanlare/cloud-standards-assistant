# Tools

Two Azure Functions (Flex Consumption, Python 3.11) that the agent calls through OpenAPI for live facts.

| Path | Role |
|---|---|
| `functions/asb_version/` | `GET /api/asb/version`: current ASB / MCSB version. `?fail=true` returns 503 for failure drills. |
| `functions/terraform_registry/` | `GET /api/terraform/azurerm/versions`: proxies `registry.terraform.io` |
| `openapi/asb-version-function.json` | Contract, with `__FUNCTION_BASE_URL__` filled at agent deploy |
| `openapi/terraform-registry.json` | Contract, with `__REGISTRY_FUNCTION_BASE_URL__` filled at agent deploy |

The Registry proxy exists because the Foundry OpenAPI tool did not reliably call the public Registry directly. The deploy workflow publishes both with `Azure/functions-action`. See [Operations](../docs/OPERATIONS.md).
