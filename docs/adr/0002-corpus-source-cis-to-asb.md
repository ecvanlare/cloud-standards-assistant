# ADR-0002: Azure Security Benchmark over CIS Benchmarks

**Status:** Accepted  
**Date:** 2026-08-30

## Context

The retrieval corpus needs four standards sources. Three of them (Azure Well-Architected Framework, NIST Cybersecurity Framework / NIST 800-53, HashiCorp Terraform docs) sit on open public URLs and can be auto-fetched.

CIS Benchmarks for Azure cover the same control area but the PDFs are gated behind a free CIS account login. An ingestion pipeline cannot fetch them. Shipping them would also require a redistribution caveat and a local, gitignored drop path (`corpus/cis/`).

Microsoft publishes **Azure Security Benchmark** on Microsoft Learn (currently titled Microsoft Cloud Security Benchmark, the successor to Azure Security Benchmark). It maps to CIS controls, is CC BY-licensed, and is available on an open URL.

## Decision

Use **Azure Security Benchmark** as the fourth corpus source instead of CIS Benchmarks for Azure.

## Rationale

- Same underlying control area as CIS Azure, with a direct mapping
- Open Microsoft Learn URL, so all four sources are 100% auto-fetchable
- No manual download step and no redistribution caveat to document

## Consequences

- `corpus/cis/` ingest is removed; licensed CIS PDFs are not part of this repo
- Azure Security Benchmark entries live in `search/corpus-manifest.json` and are fetched like WAF, NIST, and Terraform
- Eval rows that cited CIS now cite Azure Security Benchmark
- Corpus labels keep the name Azure Security Benchmark; Learn may show Microsoft Cloud Security Benchmark
