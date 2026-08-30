# Example retrieval: WAF reliability zones

**Query:** What does the Well-Architected Framework say about reliability zones?

**Index:** `corpus-tuned` (hybrid keyword + vector), `dev` (`srch-csa-dev`), after one-pass ingest (blob Metadata → projections).

## Top cited hit

| Field | Value |
|-------|--------|
| **framework** | Azure Well-Architected Framework |
| **section** | Reliability - Availability zones |
| **title** | Use availability zones |
| **source_path** | `https://stcsadev8wlu.blob.core.windows.net/corpus/waf/reliability-availability-zones.md` |
| **Source-URL (in chunk)** | https://learn.microsoft.com/azure/well-architected/reliability/regions-availability-zones |

## Snippet (retrieved `content`, trimmed)

```text
Source-URL: https://learn.microsoft.com/azure/well-architected/reliability/regions-availability-zones
Framework: Azure Well-Architected Framework
Section: Reliability - Availability zones
Title: Use availability zones

Architecture Strategies for Using Availability Zones and Regions - Microsoft Azure Well-Architected Framework | Microsoft Learn
```

## How to reproduce

```bash
./search/scripts/query-example.sh "What does the Well-Architected Framework say about reliability zones?"
```

`corpus-default` returns the same primary citation with fewer total chunks (see [`../CHUNKING.md`](../CHUNKING.md)).
