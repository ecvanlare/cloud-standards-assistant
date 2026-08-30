# Retrieval (Azure AI Search)

Index definitions, blob datasource, skillsets (chunk + embed), and hybrid query scripts for the standards corpus.

## Layout

| Path | Role |
|------|------|
| `index.json` | Hybrid index template (`content` + `contentVector` 1536-d, citation fields) |
| `datasource.json` | Blob datasource → env `corpus` container (Search MI) |
| `skillset-default.json` | Split 2000/500 + `text-embedding-3-small` |
| `skillset-tuned.json` | Split 800/150 (better for numbered controls / nested sections) |
| `indexer-*.json` | Indexers projecting chunks into `corpus-default` / `corpus-tuned` |
| `corpus-manifest.json` | Public source list (WAF, Azure Security Benchmark, NIST, Terraform) |
| `scripts/` | Fetch, upload, deploy, run indexers, example hybrid query |
| `CHUNKING.md` | Default vs tuned retrieval notes |
| `examples/` | Cited retrieval sample |

## Prerequisites

- Phase 1 `dev` stack applied (`terraform/envs/dev`)
- Search service MI has Storage Blob Data Reader + Cognitive Services User (identity module)
- Deployer has Search Index Data Contributor on the Search service (identity module — needed to query index documents; Service Contributor alone is not enough)
- Azure CLI logged in; Terraform state available for outputs

## Run (dev)

```bash
./search/scripts/fetch-corpus.sh
./search/scripts/upload-corpus.sh
./search/scripts/deploy-search.sh
./search/scripts/run-indexers.sh
./search/scripts/query-example.sh
```

## Citations

Chunks store `framework`, `section`, `title`, and `source_path`. Upload sets blob Metadata keys `citeframework` / `citesection` / `citetitle`; skillsets project them from `/document/citeframework` (not `metadata_citeframework` — that path is empty for custom keys). Hybrid queries return those fields with the content snippet.

Foundry IQ grounding is out of scope for AZP-6.
