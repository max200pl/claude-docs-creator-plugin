---
name: create-steps
scope: shared
description: "Generate a structured step-by-step runbook for any workflow — metadata block, numbered steps with action/expected output/failure hint, rollback, verification, change log. Saves as markdown."
user-invocable: true
argument-hint: "<topic> [output-path]"
---

# Create Steps

> Reference: read `docs/research-runbook-best-practices.md` — industry consensus (Google SRE, AWS OPS07-BP03, PagerDuty, Atlassian, SolarWinds) this skill implements

Generate a ready-to-follow runbook for any workflow — db migration, release, incident response, onboarding. Output is a structured markdown document with metadata, numbered steps (action + expected output + failure hint), rollback, verification, and change log.

## Usage

```text
/create-steps <topic>                       # saves to docs/steps-<slug>.md
/create-steps <topic> <output-path>         # saves to the given path
```

**Examples:**

- `/create-steps "postgres schema migration"`
- `/create-steps "release to production" release-steps.md`
- `/create-steps "incident response" .claude/runbooks/incident.md`

If `<topic>` is missing, ask the user what workflow they want steps for.

## Before writing: check for existing coverage

If a rule, doc, or skill already describes the same workflow — **reference it, do not duplicate**.

| Topic hint | Already covered by |
| ---- | ---- |
| api-skill preflight / `/add-dir` prep | `rules/api-skill-preflight.md` |
| initializing project docs | `/init-project` |
| creating a `.claude/` doc file | `/create-docs` |
| diagram authoring | `/create-mermaid`, `docs/how-to-create-mermaid.md` |

If the topic matches, the output should be a 3-5 line "see X" redirect, not a full stepped guide.

## The 5 A's (mental checklist for every runbook)

Before saving, sanity-check against:

- **Actionable** — every step is a command, not a paragraph
- **Accessible** — linkable from alerts/PRs, not buried in prose
- **Accurate** — validated by someone other than the author before publishing
- **Authoritative** — one runbook per process; no duplicates
- **Adaptable** — change log is open-ended; quarterly review is realistic

## Output structure

```markdown
# Runbook: <Topic Title>

## Metadata

| Field | Value |
| ---- | ---- |
| Runbook ID | RUN-<slug> |
| Owner | <name or team> |
| Last updated | <YYYY-MM-DD> |
| Severity | <low / medium / high / critical — if tied to an alert> |
| Desired outcome | <one sentence: what "done" looks like> |
| Tools | <cli tools, apis, consoles needed> |
| Permissions | <access required — prod read, admin, etc.> |
| Escalation POC | <who to page if stuck> |

## Overview

<One paragraph: what this runbook does, when to run it, business impact of getting it wrong.>

## Prerequisites

- <Access / role needed>
- <Tool versions>
- <Maintenance window or approvals>
- <Anything else that must be true before step 1>

## Procedure

1. **<Step name>** — <one-line purpose>
   - **Action:** `<command or action>`
   - **Expected output:** <what operator sees on success>
   - **If it fails:** <specific log / metric / command to check; escalate to <POC> if …>

2. **<Step name>** — <one-line purpose>
   - **Action:** `<command>`
   - **Expected output:** <success signal>
   - **If it fails:** <hint>

<continue — keep under 12 steps; split into ## Phase 1 / ## Phase 2 subsections if longer>

## Rollback / Abort

<What to do if aborted mid-way. Critical for destructive ops. Omit only if truly idempotent.>

## Verification

- [ ] <Post-run check 1>
- [ ] <Post-run check 2>
- [ ] <Post-run check 3 — each confirms part of the desired outcome>

## Related

- <Parent playbook, if any>
- <Child runbooks triggered from this one>
- <Relevant postmortems or incidents this runbook was born from>

## Change Log

- <YYYY-MM-DD> — <short description of what changed> — <author>
```

## Rules for good steps

- **Use `1.` for every ordered item** — Markdown auto-numbers; editing never forces renumbering (per `markdown-style.md`)
- **Step name is imperative and concrete** — "Drain the queue", not "Queue draining" or "Step 3"
- **Never put `Step N` as a heading** — violates `no-step-numbers.md`; numbers belong to the list marker, not the text
- **Three fields per step** — Action, Expected output, If it fails — never conflate
- **Every step has both expected output AND failure hint** — operator must confirm success before moving on
- **Commands are copy-pastable** — full paths, no `...` placeholders in runnable code
- **Keep under 12 steps** — if longer, split into phases (`## Phase 1: Drain`, `## Phase 2: Cutover`)
- **Metadata block is mandatory** — even a "Last updated: unknown" is better than omitting

## Slug for default filename

Lowercase, spaces → hyphens, drop punctuation:

- `"Release to production"` → `steps-release-to-production.md`
- `"Postgres schema migration v2"` → `steps-postgres-schema-migration-v2.md`

## Pre-publish reminder

After saving, tell the author:

```text
💡 Next: have a teammate run this runbook end-to-end before marking it ready.
   If they need to ask questions, the runbook is not yet Accurate.
```

## Output (after saving)

```text
╭─ /create-steps ─────────────────────────────────────────────╮
│  Topic        <topic>                                       │
│  Steps        N numbered actions (M phases)                 │
│  Saved to     <path>                                        │
│  Metadata     owner: <?>  severity: <?>  POC: <?>           │
│  Redirect     <"see X" if matched an existing pattern>      │
╰─────────────────────────────────────────────────────────────╯

💡 Next: have a teammate run this runbook end-to-end before
   marking it ready.
```

## What NOT to generate

- Generic "be careful" tips without a specific check
- Steps without an Expected output (operator can't tell if they succeeded)
- Long narrative paragraphs (slow decisions under stress)
- More than 12 steps in a single phase (split it)
- Placeholder `<your value here>` inside runnable commands
