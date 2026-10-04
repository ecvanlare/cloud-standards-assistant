# Search

Azure AI Search definitions for the standards corpus. They are data-plane objects, so `scripts/publish.sh` applies them rather than Terraform.

| File | Role |
|---|---|
| `corpus-manifest.json` | Public sources (WAF, ASB, NIST, Terraform) with citation metadata |
| `index.json` | Hybrid index: `content`, 1536-d `contentVector`, citation fields |
| `datasource.json` | Blob source, read by the Search managed identity |
| `skillset-default.json`, `skillset-tuned.json` | Split 2000/500 or 800/150, then embed with `text-embedding-3-small` |
| `indexer-default.json`, `indexer-tuned.json` | Project chunks into `corpus-default` and `corpus-tuned` |
| `scripts/publish.sh` | `fetch`, `upload`, `definitions`, `index`, or `all` |
| `examples/` | A cited retrieval sample |

Run with `make search ENV=dev`; the deploy workflow runs it on every deploy. Upload sets blob metadata `citeframework`, `citesection` and `citetitle`, which the skillsets read from `/document/cite*`.
