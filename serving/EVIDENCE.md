# Concurrent load evidence (AZP-4)

## Portal

![Replica Count (Max) — peak 2](evidence/replica-count.png)

`ca-csa-dev-serving` → Monitoring → Metrics → **Replica Count** (Max). Peak **2** under load.

## Load script (2026-09-10)

```
Serving URL: https://ca-csa-dev-serving.yellowwave-cfbff046.uksouth.azurecontainerapps.io
200 × GET /health, concurrency 40 → 200 ok / 0 err
Replicas: 1 → 2
Scale rule: http-concurrency, concurrentRequests=10, maxReplicas=5
```

## Caption

Concurrent `/health` against `ca-csa-dev-serving` on `cae-csa-dev`. HTTP scale rule drove replica count **1 → 2** (portal + `az containerapp replica list`).
