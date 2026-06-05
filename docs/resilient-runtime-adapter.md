# Resilient Runtime Adapter

This repository should call the shared resilient runtime through the dashboard API. Do not embed a duplicate runtime engine here.

Authoritative runtime owner:

```text
quantam101/already-here-dashboard
```

Runtime API base path:

```text
/api/resilient-runtime
```

## Use cases for this repo

- Publishing workflow preflight checks.
- Content metadata validation.
- SEO checklist validation.
- Export readiness checks.
- Local deterministic QA before publishing.

## Adapter endpoints

```text
GET  /api/resilient-runtime/health
POST /api/resilient-runtime/execute
GET  /api/resilient-runtime/events
```

## Required environment variable

```text
ALREADY_HERE_DASHBOARD_URL=https://app.alreadyherellc.com
```

For local development:

```text
ALREADY_HERE_DASHBOARD_URL=http://127.0.0.1:8000
```

## Example validation payload

```json
{
  "query": "validate title not null and validate score range 0 to 100 then describe",
  "records": [
    {"title": "Field Service Dispatch Guide", "score": 94, "status": "ready"}
  ],
  "schema_context": {"title": "str", "score": "number", "status": "str"},
  "session_id": "unified-publisher-operator"
}
```

## Boundary

Keep this repo focused on publishing operations. Runtime policy, audit logging, deterministic validation, and matching logic remain centralized in the dashboard.
