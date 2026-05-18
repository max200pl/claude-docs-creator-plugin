---
name: update-frontend-docs
scope: api
description: "Refresh a specific area of the frontend analysis and regenerate only the affected .claude/ artefacts. Re-invokes one or more subagents (design-system-scanner, component-inventory, data-flow-mapper, architecture-analyzer, framework-idiom-extractor) for the specified area, merges results into .claude/state/frontend-analysis.json, and regenerates only the affected .md files. Subsumes /update-docs --refresh frontend[:area]."
user-invocable: true
argument-hint: "<area> [--all-frontends]"
---

# Update Frontend Docs

> **Flow:** read `sequences/update-frontend-docs.mmd` — source of truth for execution order
> Skip policy: `rules/artefact-skip-policy.md` — when to create vs omit files on SKIP
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
| `design-system` | `design-system-scanner` | `frontend_roots[*].design_system` | `.claude/rules/frontend-design-system.md` + `.claude/docs/reference-icon-connection.md` (from `design_system.icon_pattern`) + `.claude/docs/reference-styling-flow.md` (from `design_system.styling_patterns`, schema 1.3+) |
| `components` | `component-inventory` | `frontend_roots[*].component_inventory` | `.claude/rules/frontend-components.md` + `.claude/docs/reference-component-inventory.md` + `.claude/state/component-registry.json` (create or merge-update; no markdown mirror) |
| `data-flow` | `data-flow-mapper` | `frontend_roots[*].data_flow` | `.claude/sequences/frontend-data-flow.mmd` |
| `architecture` | `tech-stack-profiler` (Wave 1 refresh) + `architecture-analyzer` | `frontend_roots[*].tech_stack` + `.architecture` | `.claude/docs/reference-architecture-frontend.md` |
| `framework-idioms` | `framework-idiom-extractor` | `frontend_roots[*].framework_idioms` | Section in `reference-component-creation-template.md` (triggers full template rewrite since idioms feed it) |
| `feature-flows` | `feature-flow-detector` | `frontend_roots[*].feature_flows` | `.claude/sequences/features/*.mmd` + `## Feature data flows` section in template |
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
| Update JSON | **this skill** | Merge subagent result into `frontend_roots[*].<area-key>`; update `generated.ts` and `generated.plugin_version` to current plugin version from `plugins/docs-creator/.claude-plugin/plugin.json`. Preserve `schema_version` as-is (Preflight already validated it matches current). |
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

**Freshness check:** if `generated.ts` is from the current session (< 1 hour ago), skip REINVOKE and go directly to Regenerate artefact — the JSON data is already current. Do NOT skip Regenerate: always regenerate the artefact files from JSON regardless of freshness, so that any new frontmatter instructions are applied.

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

- `design-system` → regenerate THREE artefacts. **TWO-STREAM scanner output protocol** (schema 1.3+):

  **Sources from scanner output** (see `agents/design-system-scanner.md` Output Format):
  - `## Summary Row` (slim YAML) — driver fields, written to `frontend-analysis.json` (handled by Phase: Update JSON above)
  - `## frontend-design-system.md` (legacy markdown body) — main rules-file body
  - `## Markdown Content` (tail-narrative subsections) — routed by `### → <path>` H3 headers

  **Regeneration steps:**

  1. **`.claude/rules/frontend-design-system.md`** (+ per-root suffix) — body from scanner's `## frontend-design-system.md` section. Prepend frontmatter (`description`, `paths:` scoping; include `token_file:` and `typography_file:` from `design_system.token_file` / `.typography_file` in JSON, or `"none"` if absent).

  2. **`.claude/docs/reference-icon-connection.md`** (+ per-root suffix) — body sourced from BOTH:
     - **JSON driver fields:** `design_system.icon_pattern.*` (connection, color_change, library_name, path_convention, wrapper_component) — render per `rules/icon-connection-doc-format.md` shape
     - **Scanner Markdown Content tail:** parse scanner's `## Markdown Content` → find `### → .claude/docs/reference-icon-connection-<root>.md` H3 → extract content between this H3 and the next `### →` (or end of `## Markdown Content`). This content contains `#### Icon examples` table + `#### Notes` prose. Append to the body after JSON-driven sections.
     - Always written when `icon_pattern` exists (required per schema 1.2+). If scanner's Markdown Content subsection is absent, write only the JSON-driven body (omit Examples/Notes sections — do NOT fabricate).

  3. **`.claude/docs/reference-styling-flow.md`** (+ per-root suffix) — body sourced from BOTH:
     - **JSON driver fields:** `design_system.styling_patterns.*` (preprocessor, bundler, build_mode, all 4 stepper fields) — render per `rules/styling-flow-doc-format.md` shape with per-preprocessor dialect templating
     - **Scanner Markdown Content tail:** parse `### → .claude/docs/reference-styling-flow-<root>.md` H3 → extract `#### Notes` content. Append after JSON-driven stepper sections.
     - Always written when `styling_patterns` exists (required per schema 1.3+).

  **Parity invariant:** `/docs-creator:create-frontend-docs` writes all three artefacts on a fresh run; `/docs-creator:update-frontend-docs design-system` MUST regenerate the same three. Prior to schema 1.3, the styling-flow artefact was skipped on update — this is the parity fix.

  **Markdown Content parsing rules** (apply to artefacts #2 and #3):
  - Find `## Markdown Content` H2 in scanner output
  - For each `### → <path>` H3 inside it, extract the body between this H3 and the next `### →` (or end of `## Markdown Content`)
  - Substitute `<root>` in the target path with per-frontend suffix (per file-naming rules above)
  - Write the extracted content (without the routing `### →` H3) to the target file, AFTER the frontmatter and JSON-driven sections
  - If scanner did not emit a particular `### →` subsection, do NOT fabricate that content — omit those sections from the artefact
- `components` → regenerate `.claude/rules/frontend-components.md` + `.claude/docs/reference-component-inventory.md` from `component_inventory`; prepend `naming_conventions:` frontmatter block to `reference-component-inventory.md`; **also always write `.claude/state/component-registry.json`** (no markdown mirror): merge if exists (preserve `figma_node_id` records, overwrite `status: "unverified"`); create fresh if not exists
- `data-flow` → regenerate `.claude/sequences/frontend-data-flow.mmd` from `data_flow.primary_flow_mermaid`
- `architecture` → regenerate `.claude/docs/reference-architecture-frontend.md` from `tech_stack` + `architecture`; ALSO regenerate `reference-component-creation-template.md` (because styling_model / class_naming in Stack section changed)
- `framework-idioms` → regenerate `reference-component-creation-template.md` (framework idioms are one of its sections)
- `feature-flows` → regenerate `.claude/sequences/features/*.mmd` from `feature_flows.diagram_groups`; ALSO update the `## Feature data flows` section in `reference-component-creation-template.md`
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
- Write new frontend artefacts that don't exist yet — with one exception: `components` area always writes `component-registry.json` (creates if missing, merges if present). For all other artefacts, run `/create-frontend-docs` first if files are missing.
- Touch project source code
- Rewrite root `CLAUDE.md` beyond the single summary line in `### Frontend`
- Invent data — subagents re-scan the code, JSON is derived from that
