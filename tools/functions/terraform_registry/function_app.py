"""HTTP proxy to the public Terraform Registry for the Standards Assistant."""

from __future__ import annotations

import json
import urllib.error
import urllib.request

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

REGISTRY_BASE = "https://registry.terraform.io"
AZURERM_VERSIONS_URL = f"{REGISTRY_BASE}/v1/providers/hashicorp/azurerm/versions"


def _http_get_json(url: str) -> tuple[int, dict | list | str]:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "cloud-standards-assistant/1.0", "Accept": "application/json"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(body)
            except json.JSONDecodeError:
                return resp.status, body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            payload = {"error": "registry_http_error", "message": body[:500]}
        return exc.code, payload
    except urllib.error.URLError as exc:
        return 502, {"error": "registry_unreachable", "message": str(exc.reason)}


def _version_strings(payload: dict) -> list[str]:
    versions = payload.get("versions") or []
    out: list[str] = []
    for item in versions:
        if isinstance(item, dict) and item.get("version"):
            out.append(str(item["version"]))
        elif isinstance(item, str):
            out.append(item)
    return out


def _version_key(version: str) -> tuple:
    """Sort key for dotted numeric versions (ignores pre-release suffixes)."""
    core = version.split("-", 1)[0]
    parts: list[int] = []
    for part in core.split("."):
        try:
            parts.append(int(part))
        except ValueError:
            parts.append(0)
    return tuple(parts)


@app.route(route="terraform/azurerm/versions", methods=["GET"])
def list_azurerm_provider_versions(req: func.HttpRequest) -> func.HttpResponse:
    """Slim live summary for hashicorp/azurerm (agent OpenAPI target)."""
    fail = (req.params.get("fail") or "").lower()
    if fail == "true":
        return func.HttpResponse(
            json.dumps({"error": "simulated_failure", "message": "fail=true requested"}),
            status_code=503,
            mimetype="application/json",
        )

    status, payload = _http_get_json(AZURERM_VERSIONS_URL)
    if status != 200 or not isinstance(payload, dict):
        return func.HttpResponse(
            json.dumps(payload if isinstance(payload, (dict, list)) else {"error": "bad_payload"}),
            status_code=status if status >= 400 else 502,
            mimetype="application/json",
        )

    versions = _version_strings(payload)
    newest_first = sorted(versions, key=_version_key, reverse=True)
    summary = {
        "provider": "hashicorp/azurerm",
        "version_count": len(versions),
        "latest": newest_first[0] if newest_first else None,
        "sample": newest_first[:5],
        "source_url": AZURERM_VERSIONS_URL,
        "notes": "Proxied live from the public Terraform Registry via dedicated Azure Function.",
    }
    return func.HttpResponse(json.dumps(summary), status_code=200, mimetype="application/json")


@app.route(route="terraform/providers/{namespace}/{provider_name}/versions", methods=["GET"])
def list_terraform_provider_versions(req: func.HttpRequest) -> func.HttpResponse:
    """Proxy live provider versions from registry.terraform.io."""
    namespace = req.route_params.get("namespace") or ""
    provider_name = req.route_params.get("provider_name") or ""
    if not namespace or not provider_name:
        return func.HttpResponse(
            json.dumps({"error": "missing_path_params", "message": "namespace and provider_name required"}),
            status_code=400,
            mimetype="application/json",
        )

    url = f"{REGISTRY_BASE}/v1/providers/{namespace}/{provider_name}/versions"
    status, payload = _http_get_json(url)
    if isinstance(payload, dict):
        payload = {
            **payload,
            "source_url": url,
            "notes": "Proxied live from the public Terraform Registry via dedicated Azure Function.",
        }
    return func.HttpResponse(
        json.dumps(payload),
        status_code=status,
        mimetype="application/json",
    )
