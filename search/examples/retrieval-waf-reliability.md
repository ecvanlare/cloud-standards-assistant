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
source scripts/tf-env.sh dev
jq -n --arg q "What does the Well-Architected Framework say about reliability zones?" \
  '{search: $q, top: 3, select: "framework,section,title,source_path",
    vectorQueries: [{kind: "text", text: $q, fields: "contentVector", k: 3}]}' \
  | curl -sS -H "Authorization: Bearer $(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)" \
      -H "Content-Type: application/json" -d @- \
      "$SEARCH_ENDPOINT/indexes/corpus-tuned/docs/search?api-version=2024-07-01" \
  | jq '.value'
```

`corpus-default` returns the same primary citation with fewer total chunks (see [Evidence](../../docs/EVIDENCE.md#chunking)).
