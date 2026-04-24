---
name: update-api-contracts-docs
scope: api
description: "Targeted refresh of a specific API/protocol doc — accepts a boundary ID, predefined axis, or any doc name. Re-runs protocol-mapper for that boundary and merges changes into the existing doc."
user-invocable: true
argument-hint: "<boundary-id | axis | doc-name> [project-path]"
---

# Update API Contracts Docs

> **Flow:** read `sequences/update-api-contracts-docs.mmd`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

**Targeted refresher.** Re-audits one boundary or section against the current codebase and merges only the changed parts into the existing doc. Much faster than a full re-scan.

## Usage

```text
/update-api-contracts-docs http-rest              # refresh HTTP boundary
/update-api-contracts-docs websocket              # refresh WebSocket boundary
/update-api-contracts-docs cpp-sciter-bridge      # refresh any custom boundary by ID
/update-api-contracts-docs reference-cpp-sciter-bridge  # update a named doc directly
/update-api-contracts-docs auth                   # shorthand axis: refresh auth section only
/update-api-contracts-docs errors                 # shorthand axis: refresh error conventions only
/update-api-contracts-docs all                    # re-run all boundaries (full refresh)
```

## Argument Resolution

The `<area>` argument is resolved in order:

1. **Predefined axis** (`http`, `auth`, `realtime`, `errors`, `all`) → updates the matching
   section(s) inside `reference-api-contracts.md`
2. **Boundary ID** from `api-contracts-analysis.json` (e.g. `http-rest`, `websocket`,
   `cpp-sciter-bridge`) → re-runs `protocol-mapper` for that boundary; updates
   `api-<boundary-id>.mmd` + the matching section in `reference-api-contracts.md`
3. **Doc name** — anything else is treated as a doc filename:
   - Look for `.claude/docs/<area>.md` first
   - Then `.claude/docs/reference-<area>.md`
   - Read the doc to identify the boundary it describes, then re-run `protocol-mapper`
     for that boundary and merge changes into the doc

If nothing resolves, show the user the list of known boundaries and existing docs.

## Preflight

| Condition | Action |
| ---- | ---- |
| Predefined axis | Require `reference-api-contracts.md` + `api-contracts-analysis.json` |
| Boundary ID | Require `api-contracts-analysis.json`; `reference-api-contracts.md` optional |
| Doc name | Require the named doc file; JSON optional (re-scan from code if absent) |
| Nothing found | List available docs + boundary IDs; ask user to clarify |

## Phases

| Phase | What happens |
| ---- | ---- |
| Preflight | Resolve area argument; find target doc(s); check what exists |
| Re-audit | Re-run `protocol-mapper` subagent for the identified boundary |
| Merge | Replace only the changed section(s); preserve everything else |
| Update JSON | Patch the matching entry in `api-contracts-analysis.json` if it exists |
| User confirmation | Show diff of affected sections; user confirms per-file |
| Write | Write merged doc(s) |
| Report | Print what changed |

## Merge Rules

- Only sections owned by the selected area are replaced — all other sections preserved verbatim.
- Companion `.mmd` diagrams (e.g. `api-<boundary-id>.mmd`) are updated when their boundary is refreshed; diff presented separately.
- `CLAUDE.md` Architecture section — NEVER touched by `update-api-contracts-docs`.

## What This Skill Does NOT Do

- Full re-scan of all boundaries (use `/analyze-api-contracts` for that)
- Create docs from scratch (use `/create-api-contracts-docs`)
- Touch `CLAUDE.md`
- Modify source code
