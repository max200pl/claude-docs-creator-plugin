---
name: create-api-contracts-docs
scope: api
description: "Materialize api-contracts-analysis.json as human-readable artefacts: reference-api-contracts.md, api-data-flow.mmd sequence diagram, optional CLAUDE.md Architecture update. Requires /analyze-api-contracts to have run first."
user-invocable: true
argument-hint: "[project-path]"
---

# Create API Contracts Docs

> **Flow:** read `sequences/create-api-contracts-docs.mmd`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`
> Mermaid style: read `rules/mermaid-style.md`

**Materializer.** Reads `.claude/state/api-contracts-analysis.json` produced by `/analyze-api-contracts` and writes human-readable documentation into the target project's `.claude/`. Does not re-scan source code.

## Prerequisites

`.claude/state/api-contracts-analysis.json` must exist. If absent, prompt user to run `/analyze-api-contracts` first.

## Usage

```text
/create-api-contracts-docs              # use json from cwd
/create-api-contracts-docs apps/web     # path hint (locates .claude/state/)
```

## What This Skill Creates

| Artefact | Path in target project | Content |
| ---- | ---- | ---- |
| Protocol reference | `.claude/docs/reference-api-contracts.md` | Endpoints table, auth flow, error conventions, real-time channels |
| Per-boundary diagram | `.claude/sequences/api-<boundary-id>.mmd` | One Mermaid sequence per boundary type found in JSON |
| Architecture update | `CLAUDE.md` (optional) | 3-5 line API summary in Architecture section |
| Run report | `.claude/state/reports/create-api-contracts-docs-<ts>.md` | Timing, artefact paths |

One diagram file per entry in `boundaries[]` — named after its `boundary_id`:

| boundary_id | Diagram path |
| ---- | ---- |
| `http-rest` | `.claude/sequences/api-http-rest.mmd` |
| `websocket` | `.claude/sequences/api-websocket.mmd` |
| `custom-rpc-electron` | `.claude/sequences/api-custom-rpc-electron.mmd` |

## Phases

| Phase | What happens |
| ---- | ---- |
| Preflight | Verify JSON exists; check existing artefacts with ages |
| Read JSON | Parse `api-contracts-analysis.json` |
| Build reference doc | Render endpoints table, auth section, errors section, realtime section |
| Build sequence diagrams | Generate one `api-<boundary-id>.mmd` per boundary in JSON |
| Stage CLAUDE.md patch | Prepare 3-5 line Architecture summary (requires user confirmation) |
| User confirmation | Present diffs; user accepts per-file |
| Write artefacts | Write accepted files |
| Report | Persist run report; print dashboard |

## Reference Doc Template

`reference-api-contracts.md` sections (only sections with findings are emitted):

- **Communication Style** — primary + secondary styles, transport, base URL(s)
- **Endpoints** — method/op, path/name, purpose, call-site count, handler location, orphan flag
- **Auth Flow** — scheme, token storage, attachment, refresh, logout
- **Error Conventions** — envelope shape, status codes, validation shape, frontend handling
- **Real-time Channels** — transport, channel/event names, direction, auth
- **Notes** — orphan endpoints, drift signals, non-conventional patterns

## Per-boundary Sequence Diagram Template

Each `api-<boundary-id>.mmd` covers the canonical round-trip for that boundary. Build from the boundary's findings in JSON.

**HTTP/REST — `api-http-rest.mmd`:**
```text
participants: Client, API Server, (Auth Server if JWT)
1. Auth login: Client → POST /auth/login → token returned
2. Authenticated request: Client (+ Bearer token) → GET /api/resource → 200 response
3. Error path: API → 401/422 → Client error handler
```

**WebSocket/SSE — `api-websocket.mmd` or `api-sse.mmd`:**
```text
participants: Client, Server
1. Connection + auth handshake
2. Server push event (event name from findings)
3. Client emit (if bidirectional)
4. Disconnect / reconnect
```

**GraphQL — `api-graphql.mmd`:**
```text
participants: Client, GraphQL Gateway, (Data Source)
1. Query/Mutation with variables
2. Resolver chain (top-level only)
3. Response / errors[] array
```

**Custom protocol — `api-<id>.mmd`:**
Describe the round-trip in plain terms based on the `description` field in JSON. Use generic `Caller` / `Handler` participant labels if the actual names are unclear.

**Style rules:** follow `rules/mermaid-style.md` — neutral theme, no hardcoded colors, short participant aliases.

## Retrofit Behavior

When `.claude/docs/reference-api-contracts.md` or any `api-*.mmd` already exists:

- Present a diff; user confirms overwrite per-file
- New boundaries in JSON → new diagram files proposed (no overwrite risk)
- Removed boundaries → orphan diagrams flagged `[WARN]` — user decides to delete or keep
- `CLAUDE.md` Architecture section — NEVER auto-overwrite; always show diff + require confirmation

## What This Skill Does NOT Do

- Re-scan source code (reads JSON only)
- Modify source code
- Generate OpenAPI / Swagger specs
- Create rules or skills
