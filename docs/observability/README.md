# Observability artifacts

See [`../OBSERVABILITY.md`](../OBSERVABILITY.md) for wiring.

## Queries

[`queries.kql`](queries.kql) — paste into Application Insights Logs for `appi-csa-dev`.

## Evidence image

[`trace-cost-per-request.png`](trace-cost-per-request.png) — generated from a live App Insights `requests` query showing Function tool-hop latency for `get_asb_version` (`operation_Id` prefix `c93fd88ea796…`, ~131 ms).

**Portal follow-up (cost / tokens):** In Foundry project Tracing, link `appi-csa-dev`, run a multi-tool turn, then capture the transaction blade that shows token or cost fields and replace/supplement this PNG. Function host telemetry is already flowing via `APPLICATIONINSIGHTS_CONNECTION_STRING`.
