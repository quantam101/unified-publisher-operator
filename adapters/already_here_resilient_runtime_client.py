from __future__ import annotations

import json
import os
import urllib.request
from typing import Any


class ResilientRuntimeClient:
    def __init__(self, base_url: str | None = None, timeout_seconds: int = 20) -> None:
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

    def validate_publication_batch(self, records: list[dict[str, Any]]) -> dict[str, Any]:
        return self.execute(
            query="validate title not null and validate channel not null then describe",
            records=records,
            schema_context={"title": "str", "channel": "str"},
            session_id="unified-publisher-operator:publication-batch",
        )

    def _request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            self.base_url + path,
            data=data,
            method=method,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
            return json.loads(response.read().decode("utf-8"))
