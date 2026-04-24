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
| Data flow diagram | `.claude/sequences/api-data-flow.mmd` | Mermaid sequence — auth + one authenticated request round-trip |
| Architecture update | `CLAUDE.md` (optional) | 3-5 line API summary in Architecture section |
| Run report | `.claude/state/reports/create-api-contracts-docs-<ts>.md` | Timing, artefact paths |

## Phases

| Phase | What happens |
| ---- | ---- |
| Preflight | Verify JSON exists; check existing artefacts with ages |
| Read JSON | Parse `api-contracts-analysis.json` |
| Build reference doc | Render endpoints table, auth section, errors section, realtime section |
| Build sequence diagram | Generate `api-data-flow.mmd` from auth + request round-trip |
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

## `api-data-flow.mmd` Coverage

One Mermaid sequence diagram covering:

1. Auth login flow (client → auth endpoint → token returned)
2. One authenticated request (client attaches token → API → response)
3. Error path (API returns error → client error handling)

If real-time is present: add one WS/SSE channel example.

## Retrofit Behavior

When `.claude/docs/reference-api-contracts.md` already exists:

- Present a diff; user confirms overwrite per-file
- `CLAUDE.md` Architecture section — NEVER auto-overwrite; always show diff + require confirmation

## What This Skill Does NOT Do

- Re-scan source code (reads JSON only)
- Modify source code
- Generate OpenAPI / Swagger specs
- Create rules or skills
