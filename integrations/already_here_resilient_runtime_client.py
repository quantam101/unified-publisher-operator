from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any


class ResilientRuntimeClientError(RuntimeError):
    pass


class ResilientRuntimeClient:
    def __init__(self, base_url: str | None = None, timeout_seconds: float = 20.0) -> None:
        self.base_url = (base_url or os.environ.get("ALREADY_HERE_DASHBOARD_URL") or "https://app.alreadyherellc.com").rstrip("/")
        self.timeout_seconds = timeout_seconds

    def health(self) -> dict[str, Any]:
        return self._request("GET", "/api/resilient-runtime/health")

    def execute(
        self,
        query: str,
        records: list[dict[str, Any]],
        schema_context: dict[str, str] | None = None,
        session_id: str = "unified-publisher-operator",
    ) -> dict[str, Any]:
        return self._request(
            "POST",
            "/api/resilient-runtime/execute",
            {
                "query": query,
                "records": records,
                "schema_context": schema_context or {},
                "session_id": session_id,
            },
        )

    def _request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            self.base_url + path,
            data=body,
            method=method,
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.URLError as exc:
            raise ResilientRuntimeClientError(f"resilient runtime request failed: {exc}") from exc
