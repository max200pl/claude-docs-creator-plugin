---
name: analyze-api-contracts
scope: api
description: "Read-only — detect and map all external communication boundaries in a target project (any protocol: REST, GraphQL, gRPC, WebSocket, message queues, custom). Two-wave fan-out: protocol-detector gating + N parallel protocol-mapper invocations. Writes .claude/state/api-contracts-analysis.json only."
user-invocable: true
argument-hint: "[project-path] [--only <boundary-id>]"
---

# Analyze API Contracts

> **Flow:** read `sequences/analyze-api-contracts.mmd`
> Phase reference: read `docs/reference-analyze-api-contracts-phases.md`
> Fan-out pattern: `docs/reference-subagent-fanout-pattern.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

**Read-only scanner.** Detects every external communication boundary in a project and maps each one using a generic specialist. Works for any protocol — standard or custom. No human-readable docs are produced here; run `/create-api-contracts-docs` after.

## What counts as a boundary

Any channel where two parts of the system exchange data across a defined interface:
HTTP/REST, GraphQL, tRPC, gRPC, WebSocket, SSE, message queues (Kafka/RabbitMQ/Redis), IPC, workers, custom in-house RPC, or anything the project defines.

## Usage

```text
/analyze-api-contracts                      # auto-detect all boundaries in cwd
/analyze-api-contracts apps/web             # hint a path
/analyze-api-contracts --only http-rest     # map only one specific boundary
/analyze-api-contracts --only websocket     # map only WebSocket boundary
```

`--only` accepts any `boundary_id` from the detector output, including custom ones.

## Execution — Two-Wave Fan-out

**Wave 1 — Detect (gating):** `protocol-detector` scans deps, config, and first-level code signals. Returns a list of boundary descriptors — one per distinct communication type found.

**Wave 2 — Map (parallel, N per boundary):** one `protocol-mapper` invocation per boundary, running concurrently. Each mapper receives its boundary descriptor and maps 4 axes: endpoints/operations, auth/security, errors/failures, call-site cross-reference. Works for any protocol including custom ones.

| Subagent | Role |
| ---- | ---- |
| `protocol-detector` | Wave 1 — detects boundary types; returns descriptor list |
| `protocol-mapper` | Wave 2 — maps ONE boundary of any type (N parallel invocations) |

Fan-out count = number of boundaries detected. Typical: 1-4. Scales without adding new agents.

## Output

Writes **only** `.claude/state/api-contracts-analysis.json`. Never writes to `.claude/docs/` or `.claude/sequences/`.

```json
{
  "skill": "analyze-api-contracts",
  "ts": "2026-04-24T12:00:00Z",
  "project_root": "/abs/path",
  "boundaries": [
    {
      "boundary_id": "http-rest",
      "label": "HTTP REST",
      "custom": false,
      "endpoints": [],
      "auth": {},
      "errors": {},
      "call_sites": {}
    },
    {
      "boundary_id": "custom-rpc-electron",
      "label": "Custom RPC: Electron IPC",
      "custom": true,
      "description": "calls sendCommand(type, payload) in renderer, handled by onCommand in main",
      "endpoints": [],
      "auth": {},
      "errors": {},
      "call_sites": {}
    }
  ],
  "summary": { "boundary_count": 2, "boundary_ids": ["http-rest", "custom-rpc-electron"] }
}
```

## Composition

| Phase | Owner |
| ---- | ---- |
| Preflight | **this skill** |
| Wave 1 — Detect boundaries | `protocol-detector` subagent (once) |
| Orientation checkpoint | **this skill** |
| Wave 2 — Map each boundary (parallel) | `protocol-mapper` subagent × N |
| Assemble + write JSON | **this skill** |
| Report | **this skill** |

Phase-by-phase implementation details: [`docs/reference-analyze-api-contracts-phases.md`](../../docs/reference-analyze-api-contracts-phases.md)

## What This Skill Does NOT Do

- Write `.claude/docs/` — use `/create-api-contracts-docs`
- Refresh existing docs — use `/update-api-contracts-docs`
- Modify source code
- Test endpoint liveness (static analysis only)
- Invent boundaries not found in code
- Document internal layer/module boundaries — see future `/analyze-layers`
