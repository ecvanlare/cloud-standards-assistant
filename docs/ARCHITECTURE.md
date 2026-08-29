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
    S --> C[(Corpus: WAF, CIS, NIST, Terraform docs)]
    A --> CS[Content Safety]
    A --> O[Control Plane tracing / App Insights]
    A --> R[Answer + citation]
```

## Agent flow

> TODO once Phase 3 lands: decision logic for retrieve vs. tool call vs. defer, with a real trace example.

## Data flow / retrieval

> TODO once Phase 2 lands: chunking strategy, embedding model, hybrid search config.

## Environments

Three environments (`dev`, `staging`, `prod`) from the same Terraform modules, see `terraform/`.

## Decisions

See [`docs/adr/`](adr) for architecture decision records, starting with [ADR-0001: Container Apps over AKS](adr/0001-compute-platform.md).
