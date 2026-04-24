---
name: update-api-contracts-docs
scope: api
description: "Targeted refresh of one area of reference-api-contracts.md — re-runs the matching specialist subagent, merges result into existing docs. Areas: http / auth / realtime / errors."
user-invocable: true
argument-hint: "<area> [project-path]"
---

# Update API Contracts Docs

> **Flow:** read `sequences/update-api-contracts-docs.mmd`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

**Targeted refresher.** Re-runs one specialist subagent for a specific axis and merges the result into the existing `.claude/docs/reference-api-contracts.md`. Much faster than a full re-scan.

## Usage

```text
/update-api-contracts-docs http           # refresh endpoints + handlers
/update-api-contracts-docs auth           # refresh auth flow section
/update-api-contracts-docs realtime       # refresh WS/SSE/queue channels
/update-api-contracts-docs errors         # refresh error conventions
/update-api-contracts-docs all            # re-run all (same as /analyze-api-contracts + /create-api-contracts-docs)
```

## Area → Specialist Mapping

| Area | Specialist re-run | Sections updated |
| ---- | ---- | ---- |
| `http` | `protocol-http-mapper` | Endpoints table, orphan list |
| `auth` | `protocol-auth-mapper` | Auth Flow section, `api-data-flow.mmd` auth fragment |
| `realtime` | `protocol-realtime-mapper` | Real-time Channels section |
| `errors` | `protocol-error-mapper` | Error Conventions section |
| `all` | all 4 specialists | all sections |

## Phases

| Phase | What happens |
| ---- | ---- |
| Preflight | Verify `reference-api-contracts.md` exists; read `api-contracts-analysis.json` for roots |
| Re-run specialist | Invoke matching subagent with current project state |
| Merge | Replace only the affected section(s) in the existing reference doc |
| Update JSON | Patch the matching key in `api-contracts-analysis.json` |
| User confirmation | Show section diff; user confirms |
| Write | Write merged doc + patched JSON |
| Report | Print what changed |

## Merge Rules

- Only the section(s) owned by the selected area are replaced — other sections are preserved verbatim.
- If `api-data-flow.mmd` needs updating (area = `http` or `auth`), present the diagram diff separately.
- `CLAUDE.md` Architecture section — NEVER touched by `update-api-contracts-docs`; only `/create-api-contracts-docs` manages it.

## What This Skill Does NOT Do

- Full re-scan (use `/analyze-api-contracts` for that)
- Create docs from scratch (use `/create-api-contracts-docs`)
- Touch `CLAUDE.md`
- Modify source code
