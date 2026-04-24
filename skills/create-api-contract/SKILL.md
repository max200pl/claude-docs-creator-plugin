---
name: create-api-contract
scope: api
description: "Spec-first contract authoring — interactive wizard that designs a new API contract (HTTP endpoint / GraphQL operation / WebSocket event / custom protocol) and writes .claude/docs/contract-<name>.md. Does not scan code; use /analyze-api-contracts to document existing contracts."
user-invocable: true
argument-hint: "[contract-name] [--type http|graphql|ws|custom]"
---

# Create API Contract

> **Flow:** read `sequences/create-api-contract.mmd`
> Output rules: read `rules/output-format.md`
> Mermaid style: read `rules/mermaid-style.md`

**Spec-first wizard.** Guides the user through designing a new API contract and writes a human-readable specification. No code is scanned — use `/analyze-api-contracts` to document contracts that already exist in code.

## Usage

```text
/create-api-contract                        # full wizard, asks everything
/create-api-contract get-user               # pre-fills name
/create-api-contract get-user --type http   # skip type selection
```

## What This Skill Creates

| Artefact | Path in target project | Content |
| ---- | ---- | ---- |
| Contract spec | `.claude/docs/contract-<name>.md` | Full spec: endpoint, shapes, auth, errors |
| Flow diagram | `.claude/sequences/contract-<name>.mmd` | Mermaid sequence — request/event round-trip |

Optionally: stub code skeletons (backend handler + frontend client function), printed to the chat for the user to copy — not written to source files.

## Wizard Phases

### Phase 1 — Protocol type

Ask (if not given via `--type`):

```text
What type of contract?
[1] HTTP endpoint (REST / RPC-over-HTTP)
[2] GraphQL operation (query / mutation / subscription)
[3] WebSocket event
[4] Custom protocol
```

### Phase 2 — Contract details

Collect per type:

| Type | Questions |
| ---- | ---- |
| HTTP | Method (GET/POST/PUT/PATCH/DELETE), path (e.g. `/api/users/:id`), purpose (one line), request body shape, response shape, auth required (y/n + scheme), possible error codes |
| GraphQL | Operation type (query/mutation/subscription), operation name, arguments with types, return type shape, auth required, possible errors |
| WebSocket | Event name, direction (client→server / server→client / both), payload shape, auth (token in handshake?), reconnect behavior |
| Custom | Protocol name, "call" shape (how caller invokes), "response" shape, transport (IPC / file / pipe / other), auth if any |

Ask questions one group at a time — not a long form dump. Start with the most essential fields, then ask for optional ones.

### Phase 3 — Generate spec

Build `.claude/docs/contract-<name>.md` using the template:

```markdown
# Contract: <name>

> Created by `/create-api-contract` on <date>.
> Type: <HTTP GET /path | GraphQL query GetUser | WS event user:message | ...>

## Purpose

<one-sentence purpose>

## Request / Invocation

<request details — method+path, or operation+variables, or event+payload>

## Response / Result

<response shape with example JSON>

## Auth

<scheme, required scopes, how token is attached>

## Errors

| Code / Status | Meaning | Shape |
| ---- | ---- | ---- |
| 401 | Unauthenticated | `{ error: { code: "UNAUTHENTICATED" } }` |
| ... | | |

## Notes

<constraints, versioning, deprecation plans — optional>
```

### Phase 4 — Generate sequence diagram

Create `contract-<name>.mmd` showing the round-trip for this contract:
- HTTP: client → auth check → handler → response / error
- GraphQL: client → resolver → data source → response
- WS: emit → server handler → ack or push-back
- Custom: caller → handler → result

### Phase 5 — Optional stubs

Ask: "Generate code stubs? [1] Backend handler + frontend client  [2] Backend only  [3] Frontend only  [4] Skip"

If accepted: print stubs in a code block in the chat. Do NOT write to source files — the user copies them where appropriate.

## What This Skill Does NOT Do

- Scan existing code (use `/analyze-api-contracts` for that)
- Write to source files — stubs are printed to chat only
- Generate OpenAPI / Swagger YAML — use a dedicated tool for that
- Create database schemas or migrations
