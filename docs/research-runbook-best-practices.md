# Research: Step-by-Step Runbook Best Practices

> Date: 2026-04-17
> Topic: Industry conventions for step-by-step runbooks / playbooks, to inform `/create-steps` skill design
> Sources: Google SRE, PagerDuty, Atlassian, AWS Well-Architected, SolarWinds, Rootly, community blogs

## The "5 A's" framework

A trustworthy runbook must be **Actionable, Accessible, Accurate, Authoritative, Adaptable** — shared vocabulary across SolarWinds, Rootly, and Atlassian guides. Each letter maps to a concrete check:

- **Actionable** — every step is a command, not a paragraph
- **Accessible** — findable from the alert itself (linked in PagerDuty/Slack, not buried in a wiki)
- **Accurate** — validated by someone other than the author before publishing
- **Authoritative** — single source of truth, one runbook per process, versioned
- **Adaptable** — quarterly review cadence, updated after every post-incident review

## Required metadata block

Every source agrees: metadata must live at the top in a scannable block, not in prose. AWS Well-Architected OPS07-BP03 publishes a template runbook table:

| Field | Why |
| ---- | ---- |
| Runbook ID | Cross-reference from alerts, tickets, other runbooks |
| Owner / POC | Who maintains and answers questions |
| Last updated | Staleness signal — quarterly review target |
| Tools used | Dependencies that must be installed/accessible |
| Special permissions | Access needed (e.g. admin, prod read, PagerDuty write) |
| Escalation POC | Who to page if stuck |
| Desired outcome | What "done" looks like |
| Severity / impact | If tied to an alert — drives urgency |

## Step format conventions

Synthesized from Google SRE, PagerDuty, SolarWinds, AWS:

- **Numbered, action-first, imperative** — "Drain the queue", not "Queue draining"
- **One command per step** — if a step has "and then", split it
- **Expected output after each step** — operator sees success before moving on (distinct from the "if it fails" branch)
- **Inline failure hint** — short, specific, names a log / metric / command to check
- **Copy-paste-safe commands** — full paths, no `...` placeholders in code
- **Escalation fallback** — every step ends with "if still stuck: contact `<POC>`" at the latest at the bottom of the section
- **Under ~12 steps** — longer → split into phases

## Required sections beyond the checklist

Every industry template includes:

- **Overview** — one paragraph: what, when, why (business impact)
- **Prerequisites** — access, tools, versions, maintenance window, approvals
- **Procedure** — the numbered steps (the core)
- **Rollback / Abort** — what to do if aborted mid-way (critical for destructive ops)
- **Verification** — quick checklist to confirm success after running all steps
- **Related** — links to parent playbook, child runbooks, postmortems
- **Change log** — append-only list of dated edits (anti-drift)

## Google SRE specifics

- **Playbooks deliver ~3× MTTR improvement** vs winging it (sre.google)
- **Every alert has a matching playbook entry** — no orphan alerts
- **New alerts get the same review as new code** — PR + sign-off
- **Learning checklists** are separate from procedural runbooks — they enumerate expert contacts, key docs, and probing questions, not recipes

## Common anti-patterns (from AWS OPS07-BP03)

- Relying on memory instead of written steps
- Manually deploying changes without a checklist
- Different team members doing the same process differently
- Runbooks drifting out of sync with system changes
- Long narrative paragraphs where decisions must be fast

## Automation as the next evolution

All sources (AWS, SolarWinds, Harness, PagerDuty) push: **start with a Markdown runbook, then automate the most-used/highest-friction steps**. Don't skip the text version — it's the spec that the automation later implements.

## Current `/create-steps` vs best practices

| Practice | Current `create-steps` | Status |
| ---- | ---- | ---- |
| Numbered list with `1.` for every item | Yes | ✓ |
| Imperative step names | Yes | ✓ |
| One action per bullet | Yes | ✓ |
| Failure hint per step | Yes | ✓ |
| Copy-pastable commands | Yes | ✓ |
| Under 12 steps | Yes | ✓ |
| Overview + Prereqs up front | Yes (Context / Audience / Prereqs) | ✓ |
| Rollback + Verification sections | Yes | ✓ |
| **Metadata block (owner, last updated, severity, escalation POC)** | No | **Missing** |
| **Desired outcome explicit** | Implicit in Context | Partial |
| **Expected output per step** (separate from failure) | No | **Missing** |
| **Change log / version trail** | No | **Missing** |
| **Related runbooks section** | No | **Missing** |
| **Automation hint per step** | No | Nice-to-have |
| **Validation step before publishing** | No | Nice-to-have |

## Gaps / Opportunities

| Gap | Priority | Why |
| ---- | ---- | ---- |
| No metadata block (owner / updated / severity / POC) | High | Industry-standard; enables staleness tracking and escalation |
| No "expected output" per step | High | Critical for operator to confirm success before next step — orthogonal to "if it fails" |
| No Change Log / Last-updated field | Medium | Quarterly review cadence depends on this signal |
| No "Related runbooks" / parent-playbook links | Medium | Runbooks rarely exist in isolation |
| No automation-maturity hint (which steps are candidates for scripting) | Low | Optional evolution path |
| No validation step ("have someone else run it") | Low | Process concern, not content |

## Recommendations

1. **Add metadata block to `/create-steps` output template** — owner, last updated, severity, tools, permissions, escalation POC, desired outcome. Model after AWS OPS07-BP03 table.
2. **Split per-step content into three fields** — Action, Expected output, If it fails. Current skill conflates expected output with action.
3. **Add a Change Log section** at the bottom (append-only dated edits).
4. **Add a Related section** — links to parent playbooks, child runbooks, relevant postmortems.
5. **Add a pre-publish validation note** — `/create-steps` should remind the author: "Have someone else run this before marking ready."
6. **Keep the 5 A's front and center** in the skill's "Rules for good steps" section — they're the mental checklist every author should hold.

## Sources

- [Google SRE Workbook — On-Call](https://sre.google/workbook/on-call/) — playbooks give ~3× MTTR improvement; every alert has an entry
- [Google SRE Book — Being On-Call](https://sre.google/sre-book/being-on-call/) — learning checklists vs procedural runbooks
- [PagerDuty Incident Response Documentation](https://response.pagerduty.com/) — incident response playbook structure
- [Atlassian — How to create an incident response playbook](https://www.atlassian.com/incident-management/incident-response/how-to-create-an-incident-response-playbook) — roles, severity classification, simplicity
- [Atlassian Confluence — DevOps runbook template](https://www.atlassian.com/software/confluence/templates/devops-runbook) — template structure
- [AWS Well-Architected OPS07-BP03](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/ops_ready_to_support_use_runbooks.html) — canonical runbook template with metadata table, anti-patterns, implementation steps
- [SolarWinds — Runbook Template Best Practices](https://www.solarwinds.com/sre-best-practices/runbook-template) — 5 A's framework
- [Rootly — Incident Response Runbooks](https://rootly.com/incident-response/runbooks) — structure, writing style, continuous improvement
- [Christian Emmer — An Effective Incident Runbook Template](https://emmer.dev/blog/an-effective-incident-runbook-template/) — field-by-field template walkthrough
- [Harness Developer Hub — Create Runbooks](https://developer.harness.io/docs/ai-sre/runbooks/create-runbook/) — automation evolution
