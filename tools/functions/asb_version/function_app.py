"""HTTP tool for the Standards Assistant (ASB version lookup)."""

from __future__ import annotations

import json
import time

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Curated public metadata for demos. Update when Microsoft publishes a new MCSB revision.
ASB_VERSION_PAYLOAD = {
    "framework": "Azure Security Benchmark",
    "also_known_as": "Microsoft cloud security benchmark (MCSB)",
    "version": "v2",
    "revision": "2025-public",
    "source_url": "https://learn.microsoft.com/security/benchmark/azure/introduction",
    "notes": "Live revision label for portfolio tool demos; prefer Learn for authoritative text.",
}


@app.route(route="asb/version", methods=["GET"])
def get_asb_version(req: func.HttpRequest) -> func.HttpResponse:
    """Return current ASB/MCSB version metadata for the agent tool."""
    fail = (req.params.get("fail") or "").lower() in ("1", "true", "yes")
    sleep_ms = req.params.get("sleep_ms")

    if sleep_ms:
        try:
            time.sleep(max(0, min(int(sleep_ms), 120_000)) / 1000.0)
        except ValueError:
            return func.HttpResponse(
                json.dumps({"error": "invalid_sleep_ms", "message": "sleep_ms must be an integer"}),
                status_code=400,
                mimetype="application/json",
            )

    if fail:
        return func.HttpResponse(
            json.dumps(
                {
                    "error": "forced_failure",
                    "message": "Simulated Function failure for agent retry/defer demos.",
                }
            ),
            status_code=503,
            mimetype="application/json",
        )

    return func.HttpResponse(
        json.dumps(ASB_VERSION_PAYLOAD),
        status_code=200,
        mimetype="application/json",
    )
