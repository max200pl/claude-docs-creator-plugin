---
name: update-frontend-docs
scope: api
description: "Refresh a specific area of the frontend analysis and regenerate only the affected .claude/ artefacts. Re-invokes one or more subagents (design-system-scanner, component-inventory, data-flow-mapper, architecture-analyzer, framework-idiom-extractor) for the specified area, merges results into .claude/state/frontend-analysis.json, and regenerates only the affected .md files. Subsumes /update-docs --refresh frontend[:area]."
user-invocable: true
argument-hint: "<area> [--all-frontends]"
---

# Update Frontend Docs

> **Flow:** read `sequences/update-frontend-docs.mmd` — source of truth for execution order
> Analysis source: reads + writes `.claude/state/frontend-analysis.json`
> Subagent specs: re-invokes one of `agents/{design-system-scanner, component-inventory, data-flow-mapper, architecture-analyzer, framework-idiom-extractor}.md` based on `<area>`
> Primary-output format: `rules/component-creation-template-format.md`
> Style rules: read `rules/markdown-style.md`, `rules/mermaid-style.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

Targeted refresh. User knows a specific area of the frontend drifted (design tokens changed, new components landed, data-flow rewired) — this skill re-invokes only the subagent for that area, updates the JSON in place, and regenerates only the affected `.md` artefacts.

If the project needs a FULL refresh, run `/analyze-frontend` (to regenerate the whole JSON) + `/create-frontend-docs` (to regenerate all artefacts) instead.

## Valid `<area>` values

| `<area>` | Re-invokes | Updates in JSON | Regenerates artefact |
| ---- | ---- | ---- | ---- |
| `design-system` | `design-system-scanner` | `frontend_roots[*].design_system` | `.claude/rules/frontend-design-system.md` |
| `components` | `component-inventory` | `frontend_roots[*].component_inventory` | `.claude/rules/frontend-components.md` + `.claude/docs/reference-component-inventory.md` |
| `data-flow` | `data-flow-mapper` | `frontend_roots[*].data_flow` | `.claude/sequences/frontend-data-flow.mmd` |
| `architecture` | `tech-stack-profiler` (Wave 1 refresh) + `architecture-analyzer` | `frontend_roots[*].tech_stack` + `.architecture` | `.claude/docs/reference-architecture-frontend.md` |
| `framework-idioms` | `framework-idiom-extractor` | `frontend_roots[*].framework_idioms` | Section in `reference-component-creation-template.md` (triggers full template rewrite since idioms feed it) |
| `template` | (none — re-assembles only) | no JSON change | `.claude/docs/reference-component-creation-template.md` only |

`template` is useful when the rule `component-creation-template-format.md` changes and you want to re-emit the template from existing JSON without re-running any subagent.

## Usage

```text
/update-frontend-docs design-system          # refresh only tokens + design-system rule
/update-frontend-docs components             # refresh component inventory + rule
/update-frontend-docs data-flow              # refresh data-flow diagram
/update-frontend-docs architecture           # refresh stack + architecture doc
/update-frontend-docs framework-idioms       # refresh framework rules in template
/update-frontend-docs template               # re-assemble template from current JSON (no subagent re-run)
/update-frontend-docs <area> --all-frontends # apply to every frontend in JSON (default: prompt per frontend if N > 1)
```

## Interactive Wizard

| After phase | What to show | What to ask |
| ---- | ---- | ---- |
| Preflight | Latest JSON age + which frontends exist | If JSON missing: stop with pointer to `/analyze-frontend`. If N frontends > 1 and no `--all-frontends` flag: which frontend(s) to target? |
| Subagent refresh | Per-frontend subagent output summary | Preview diff vs old JSON section. Accept / skip? |
| Regenerate artefact | Line count + diff against existing .md | Write / skip? |

## Composition

| Phase | Owner | Responsibility |
| ---- | ---- | ---- |
| Preflight | **this skill** | Read `.claude/state/frontend-analysis.json`; validate `<area>` is known; confirm frontend scope |
| Re-invoke subagent | 1-2 subagents matching `<area>` | Fresh scan of the area with current `stack_profile` from JSON |
| Update JSON | **this skill** | Merge subagent result into `frontend_roots[*].<area-key>`; update `generated.ts` |
| Regenerate artefact | **this skill** | Write only the `.md` / `.mmd` files impacted by the area |
| Update CLAUDE.md (conditional) | **this skill** | Only if area = `architecture` or `framework-idioms` (which affect the top-level summary) — refresh the `### Frontend` subsection paragraph. Other areas don't touch CLAUDE.md. |
| Report | **this skill** | Persist run report per `rules/report-format.md` |

## Reference

### Phase: Preflight

Capture `START_TS`. Read `.claude/state/frontend-analysis.json`. Error cases:

- JSON missing → stop with: "No frontend analysis found. Run `/analyze-frontend` first (and then `/create-frontend-docs` to produce initial artefacts)."
- `schema_version` mismatch → stop with: "Analysis schema version mismatch. Re-run `/analyze-frontend` to regenerate."
- `<area>` argument missing or not in the valid list → stop with the valid-area table.

Determine scope:

- If JSON has 1 frontend → proceed on that frontend.
- If JSON has N > 1 frontends:
  - `--all-frontends` flag set → apply to all.
  - No flag → interactive prompt: which frontend(s)?

### Phase: Re-invoke subagent

For each in-scope frontend, invoke the subagent(s) matching `<area>`:

```text
design-system   → design-system-scanner
components      → component-inventory
data-flow       → data-flow-mapper
architecture    → tech-stack-profiler + architecture-analyzer (both — architecture depends on fresh stack profile)
framework-idioms → framework-idiom-extractor
template        → (no subagent — skip this phase entirely, proceed to Regenerate)
```

Invocation prompt includes the SAME fields as analyze-frontend's Wave 2 (frontend_root, project_root, stack_profile, entry_points, style_rules_path, target_file_shape). For `architecture`, the stack_profile comes from a FRESH tech-stack-profiler run, not the stale JSON.

Return shape: `## Summary Row` + `## <Artefact>` — identical to `/analyze-frontend` Wave 2 contract.

### Phase: Update JSON

Read current JSON. Locate `frontend_roots[i].<area-key>` for each in-scope frontend. Replace with fresh subagent output.

For `architecture`, update both `frontend_roots[i].tech_stack` (from fresh tech-stack-profiler) and `frontend_roots[i].architecture` (from fresh architecture-analyzer).

Update `generated.ts` to current ISO timestamp. Leave `generated.only_filter` empty (this is an update, not a filtered analyze).

Write JSON back atomically (temp-write + rename).

### Phase: Regenerate artefact

Based on `<area>`:

- `design-system` → regenerate only `.claude/rules/frontend-design-system.md` from `design_system` + new frontmatter `paths:` scoping
- `components` → regenerate `.claude/rules/frontend-components.md` + `.claude/docs/reference-component-inventory.md` from `component_inventory`
- `data-flow` → regenerate `.claude/sequences/frontend-data-flow.mmd` from `data_flow.primary_flow_mermaid`
- `architecture` → regenerate `.claude/docs/reference-architecture-frontend.md` from `tech_stack` + `architecture`; ALSO regenerate `reference-component-creation-template.md` (because styling_model / class_naming in Stack section changed)
- `framework-idioms` → regenerate `reference-component-creation-template.md` (framework idioms are one of its sections)
- `template` → regenerate `reference-component-creation-template.md` from current JSON (no subagent ran)

Use the same file-naming rules as `/create-frontend-docs` (suffix per frontend when N > 1).

### Phase: Update CLAUDE.md (conditional)

Only for `architecture` and `framework-idioms` (and `template` if cross-references changed) — refresh the summary line in the `### Frontend` subsection of root `CLAUDE.md` (`Stack: <framework> with <styling>`). For other areas, CLAUDE.md is unchanged.

### Phase: Report

Write report to `.claude/state/reports/update-frontend-docs-<DISPLAY_TS>.md`.

**First-line metadata** (per `rules/report-format.md`):

```text
<!-- report: skill=update-frontend-docs ts=<ISO-UTC> wall_clock_sec=<int> frontends=<N> artefacts=<int> area=<area> stack=<aggregated> -->
```

Per-phase timings REQUIRED: `PREFLIGHT`, `REINVOKE`, `UPDATE_JSON`, `REGENERATE`, `UPDATE_CLAUDE_MD` (if applicable), `REPORT`.

Body:

- `## Summary` — area refreshed, frontends scoped, duration, artefact count
- `## Phase Timings` — per-phase
- `## Diff summary` — what changed in JSON vs previous state (key-level, not full content) + which artefacts were regenerated
- `## Next-step Recommendations` — if `framework-idioms` or `architecture` was updated, remind that downstream component-creation agents should re-read the template

## Relationship to `/update-docs --refresh frontend`

This skill **replaces** the `--refresh frontend[:area]` flag on `/update-docs`. The flag is deprecated as of plugin version 0.13.0 — it will print a deprecation notice and delegate to `/update-frontend-docs <area>` via skill chain.

Why separate skill instead of keeping the flag:

- Clearer intent (`/update-frontend-docs components` reads more obviously than `/update-docs . --refresh frontend:components`)
- Valid `<area>` values are documented in one place (this skill's argument-hint + usage table)
- Report format is distinct — this skill's report has `area=<area>` metadata, whereas `/update-docs`'s doesn't
- Consistent with toolkit's split pattern (specific skill per specific task)

## What This Skill Does NOT Do

- Full re-analysis — use `/analyze-frontend` + `/create-frontend-docs`
- Write new frontend artefacts that don't exist yet — this skill refreshes EXISTING ones. Run `/create-frontend-docs` first if some files are missing.
- Touch project source code
- Rewrite root `CLAUDE.md` beyond the single summary line in `### Frontend`
- Invent data — subagents re-scan the code, JSON is derived from that
