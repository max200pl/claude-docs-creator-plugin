# Reference — `/analyze-api-contracts` Phases

> Orchestrator SKILL: `skills/analyze-api-contracts/SKILL.md`
> Subagents: `agents/protocol-detector.md` (Wave 1), `agents/protocol-mapper.md` (Wave 2, invoked N times)

Phase-by-phase implementation details. Flow lives in `sequences/analyze-api-contracts.mmd`.

## Phase: Preflight

Owned by the orchestrator.

- Verify `.claude/` exists in cwd — if absent, direct user to `/init-project` and abort.
- Capture `START_TS` (unix epoch), `RUN_TS` (ISO 8601), `DISPLAY_TS` (human-readable) per `rules/report-format.md`.
- Read `.claude/state/api-contracts-analysis.json` age if present.
- Age buckets: `✓` < 30 days, `⚠` 30-90 days, `✗` > 90 days or missing.

## Phase: Wave 1 — Detect Boundaries

Delegated to `protocol-detector` subagent. Returns:

```json
{
  "boundaries": [
    {
      "id": "http-rest",
      "label": "HTTP REST",
      "signals": ["axios in package.json", "fetch( in 14 files"],
      "confidence": "high",
      "frontend_roots": ["/project/apps/web"],
      "backend_roots": ["/project/apps/api"]
    }
  ]
}
```

If `boundaries` is empty — abort with: "No external communication found."

## Phase: Orientation (checkpoint)

Show the user the detected boundaries with confidence levels and the age of existing JSON. Offer:

```text
Found 2 boundaries:
  • http-rest          (high)
  • custom-rpc-electron (low — verify before mapping)

Existing JSON: ⚠ 45 days old

[1] Map all
[2] --only http-rest
[3] --only custom-rpc-electron
[4] Skip — data is recent enough
```

If user selects `[4]` — abort cleanly. Otherwise proceed with the selected filter.

## Phase: Wave 2 — Map Each Boundary

Orchestrator fans out `protocol-mapper` once per boundary in the filter. All run in parallel. Each receives its full boundary descriptor from Wave 1 plus `project_root`.

The `protocol-mapper` agent is protocol-agnostic — it infers how to map based on the boundary `id`, `label`, and `signals`. Custom protocols are described in plain terms.

**Fan-out sizing:** one mapper per boundary. Typical projects have 1-4 boundaries → 1-4 parallel invocations. Each mapper is ~5k tokens of deep analysis. Main context receives compact JSON summaries only. Scales to any number of boundary types without new agents.

On mapper failure: log `(boundary_id, error)` in the report `Notes` and continue. Never abort for a single failure.

## Phase: Assemble + Write JSON

Merge all mapper outputs into:

```json
{
  "skill": "analyze-api-contracts",
  "ts": "<RUN_TS>",
  "project_root": "<abs path>",
  "boundaries": [
    {
      "boundary_id": "http-rest",
      "label": "HTTP REST",
      "custom": false,
      "endpoints": [],
      "auth": {},
      "errors": {},
      "call_sites": {}
    }
  ],
  "summary": {
    "boundary_count": 2,
    "boundary_ids": ["http-rest", "websocket"]
  }
}
```

Write to `.claude/state/api-contracts-analysis.json`. Overwrite if already exists.

## Phase: Report

Persist per `rules/report-format.md`. Print on-screen:

```text
╭─ /analyze-api-contracts ────────────────────────────────────╮
│  Boundaries  2: http-rest, websocket                        │
│  Endpoints   42 (http-rest) · 8 events (websocket)         │
│  Auth        JWT-Bearer / httpOnly-cookie                   │
│  JSON saved  .claude/state/api-contracts-analysis.json      │
│  Duration    28s                                            │
│                                                             │
│  Next: /create-api-contracts-docs                           │
╰─────────────────────────────────────────────────────────────╯
```

## Boundary ID Conventions

`protocol-detector` returns free-form IDs. Common values:

| id | Protocol |
| ---- | ---- |
| `http-rest` | HTTP REST |
| `graphql` | GraphQL |
| `trpc` | tRPC |
| `grpc` | gRPC |
| `websocket` | WebSocket / socket.io |
| `sse` | Server-Sent Events |
| `message-queue` | Kafka / RabbitMQ / Redis pub/sub |
| `ipc` | IPC / worker_threads |
| `custom-rpc-<name>` | Custom in-house protocol |

Custom IDs are valid — `protocol-mapper` handles them by reading the signals and inferring the mapping strategy.
