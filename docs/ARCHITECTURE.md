# Architecture

> This document is filled in incrementally as each phase lands. Skeleton below mirrors the README's promised sections.

## Overview

Corpus → Azure AI Search → Foundry Agent Service → Tools → Answer (with citation), with the Foundry Control Plane observing every hop and Content Safety guarding input/output.

```mermaid
flowchart LR
    U[User] --> A[Agent - Foundry Agent Service]
    A -->|retrieve| S[Azure AI Search]
    A -->|tool call| T1[Azure Function]
    A -->|tool call| T2[MCP / external API]
    S --> C[(Corpus: WAF, ASB, NIST, Terraform docs)]
    A --> CS[Content Safety]
    A --> O[Control Plane tracing / App Insights]
    A --> R[Answer + citation]
```

## Agent flow

> TODO once Phase 3 lands: decision logic for retrieve vs. tool call vs. defer, with a real trace example.

## Data flow / retrieval

Corpus blobs in the private storage `corpus` container are indexed by Azure AI Search.

1. **Ingest** — Indexer reads blobs (Search system-assigned identity).
2. **Chunk** — Text Split skill (`skillset-default`: 2000/500 pages; `skillset-tuned`: 800/150 for numbered controls and nested sections).
3. **Embed** — Azure OpenAI Embedding skill calls Foundry deployment `text-embedding-3-small` (1536 dimensions) with the Search managed identity.
4. **Store** — Index projections write child chunks into `corpus-default` or `corpus-tuned` with citation fields: `framework`, `section`, `title`, `source_path`, `content`, `contentVector`.
5. **Retrieve** — Hybrid query (keyword `search` + `vectorQueries` text-to-vector via the index vectorizer).

All four sources are fetched from public URLs by [`search/scripts/fetch-corpus.sh`](../search/scripts/fetch-corpus.sh); see [INFRASTRUCTURE.md](INFRASTRUCTURE.md#corpus-sources) and [ADR-0002](adr/0002-corpus-source-cis-to-asb.md). Foundry IQ managed grounding is deferred past Phase 2.

Details and scripts: [`search/`](../search/). Chunking comparison: [`search/CHUNKING.md`](../search/CHUNKING.md).

## Environments

Three environments (`dev`, `staging`, `prod`) from the same Terraform modules, see `terraform/`.

## Decisions

See [`docs/adr/`](adr) for architecture decision records: [ADR-0001: Container Apps over AKS](adr/0001-compute-platform.md), [ADR-0002: Azure Security Benchmark over CIS Benchmarks](adr/0002-corpus-source-cis-to-asb.md).
