---
name: create-frontend-docs
scope: api
description: "Materialize the latest frontend analysis (from .claude/state/frontend-analysis.json) as human-readable .claude/ artefacts — reference-component-creation-template.md primary + supporting references + root CLAUDE.md Architecture section update. Requires a prior /analyze-frontend run to produce the JSON."
user-invocable: true
argument-hint: "[--force-rerun] [--only <area>]"
---

# Create Frontend Docs

> **Flow:** read `sequences/create-frontend-docs.mmd` — source of truth for execution order
> Primary-output format: `rules/component-creation-template-format.md`
> Analysis source: reads `.claude/state/frontend-analysis.json` — produced by `/analyze-frontend`
> Style rules: read `rules/markdown-style.md`, `rules/mermaid-style.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

Materializes the structured analysis from `/analyze-frontend` into human-readable `.claude/` documentation. **Does no code reading / analysis itself** — purely a JSON → MD transformation + file writer. If the JSON is missing or stale, the skill stops and directs the user to run `/analyze-frontend` first.

Primary output remains `reference-component-creation-template.md` — the context envelope for a downstream component-creation agent. Supporting references (design-system rule, components rule, architecture doc, inventory, data-flow mermaid) are cross-linked from the template.

## What this skill creates

All artefacts land in the target project's `.claude/` and the root `CLAUDE.md`. Filenames use a root-derived suffix when `frontend_analysis.json` has multiple frontends, plain names otherwise.

**Primary:**

- `.claude/docs/reference-component-creation-template.md` — prescriptive recipe per [rules/component-creation-template-format.md](../../rules/component-creation-template-format.md)

**Supporting references (cross-linked from template):**

- `.claude/rules/frontend-design-system.md` — design tokens rule with `paths:` scoping
- `.claude/rules/frontend-components.md` — component conventions rule with `paths:` scoping
- `.claude/docs/reference-architecture-frontend.md` — Stack + Architecture sections (merged from `tech_stack` + `architecture` + `framework_idioms` in JSON)
- `.claude/docs/reference-component-inventory.md` — notable-components reference table
- `.claude/sequences/frontend-data-flow.mmd` — state + API flow Mermaid diagram

**Surgical CLAUDE.md update:**

- Root `CLAUDE.md` — adds a `### Frontend` subsection under `## Architecture` with `@`-imports to all new artefacts. Replaces existing `### Frontend` subsection if present; does not touch other sections.

**Operational:**

- `.claude/state/reports/create-frontend-docs-<ts>.md` — run report (gitignored)

## Usage

```text
/create-frontend-docs                  # materialize latest analysis as docs
/create-frontend-docs --force-rerun    # force analyze-frontend first, then create (chain)
/create-frontend-docs --only components # regenerate only frontend-components.md + reference-component-inventory.md
```

`--only` accepts the same areas as `/analyze-frontend`: `design-system`, `components`, `data-flow`, `architecture`, `framework-idioms`, `all`. It filters WRITES — it doesn't re-run analysis. (For re-analyzing + rewriting a single area, use `/update-frontend-docs <area>`.)

## Interactive Wizard

| After phase | What to show | What to ask |
| ---- | ---- | ---- |
| Preflight | JSON age + frontend count | If JSON is `>30 days old` — warn and offer to re-run `/analyze-frontend` first |
| Assemble | Draft reference-component-creation-template.md line count + per-frontend summary | Write all artefacts? Any to skip? |
| Report | Dashboard + list of written files + path to report | — |

## Composition

| Phase | Owner | Responsibility |
| ---- | ---- | ---- |
| Preflight | **this skill** | Confirm `.claude/` exists; read `.claude/state/frontend-analysis.json`; validate schema_version; check freshness; capture `START_TS` |
| Assemble primary template | **this skill** | Build `reference-component-creation-template.md` per `rules/component-creation-template-format.md`, populating from JSON fields |
| Confirm with user | **this skill** | Show draft line count + per-frontend summary; accept / skip per artefact |
| Write artefacts | **this skill** | Write primary + 5 references; apply `paths:` frontmatter to the 2 rule files |
| Update root CLAUDE.md | **this skill** | Surgical edit: add/replace `### Frontend` subsection under `## Architecture`; no other sections touched |
| Report | **this skill** | Persist run report per `rules/report-format.md` |

## Reference

The sequence diagram defines order. Sections below describe only non-trivial logic.

### Phase: Preflight

Capture start timestamp + read JSON:

```bash
Bash: START_TS=$(date +%s); RUN_TS=$(date -u +%Y%m%dT%H%M%SZ); DISPLAY_TS=$(date +%Y%m%d-%H%M%S); echo "START_TS=$START_TS ..."
```

Read `.claude/state/frontend-analysis.json`. Error cases:

- File missing → stop: "No frontend analysis found. Run `/analyze-frontend` first."
- `schema_version` field not matching the skill's expected (currently `1.0`) → stop: "Analysis schema version mismatch. Re-run `/analyze-frontend` to regenerate."
- `generated.ts` older than 30 days → warn but proceed unless `--force-rerun`.
- `frontend_roots` empty → stop: "Analysis has no frontend roots. Re-run `/analyze-frontend`."

`--force-rerun` flag → invoke `/analyze-frontend` first (via skill chain), then proceed with the fresh JSON. Not auto-invoke; just prompts user to do it if they pass the flag.

### Phase: Assemble primary template

Build `.claude/docs/reference-component-creation-template.md` from JSON per the section-feeding map in [rules/component-creation-template-format.md](../../rules/component-creation-template-format.md). Concrete mapping:

| Template section | JSON source |
| ---- | ---- |
| File layout | `architecture.top_level_dirs` + `component_inventory.components_dir_primary` + `component_inventory.folder_structure` |
| Imports block | `component_inventory.canonical_skeleton_excerpt` (first N import lines) + `architecture.path_aliases` |
| Props declaration | `component_inventory.primary_prop_type`, `ref_forwarding`, `naming_convention` |
| Styling model | `tech_stack.styling_model` — render as prescriptive paragraph |
| Class naming | `tech_stack.class_naming` + `tech_stack.custom_class_prefix` — include "are classes used?" definitive answer |
| State and data wiring | `data_flow.state_containers`, `data_flow.data_fetching`, `data_flow.forms`, `data_flow.authentication` |
| Event handling | `component_inventory.event_handler_convention` |
| Accessibility patterns | `component_inventory.a11y_observations` (or "None systematically observed") |
| Test and story conventions | `component_inventory.test_colocation`, `storybook_present`, `storybook_coverage_pct` |
| Design-token usage | `design_system.mechanism` + 1-2 examples from `design_system.color_palette` / `typography` |
| Framework-specific idioms | `framework_idioms.body_markdown` (verbatim — already formatted by the subagent) |
| Canonical skeleton | `component_inventory.canonical_skeleton_excerpt` verbatim |
| Anti-patterns | Union of Notes flagged as anti-patterns across all subagents |
| Cross-references | Auto-generated `@`-links to the 5 reference files |

If a JSON section is `null` or SKIP (subagent returned SKIP during analysis), the corresponding template section becomes a single-line "not observed in this project" explanation — not omitted entirely.

### Phase: Write artefacts

File-naming:

- `frontend_roots.length == 1` → plain filenames (`reference-component-creation-template.md`, `frontend-design-system.md`, etc.)
- `frontend_roots.length > 1` → suffix `-<root-slug>` derived from `frontend_roots[i].relative` basename

**Paths-scoping for generated rules — exact frontmatter blocks to prepend:**

`frontend-design-system.md`:

```yaml
---
description: Design system tokens and styling conventions for <framework> frontend at <relative_root>. Applies when editing CSS/SCSS/styling files in the frontend root.
paths:
  - "<frontend_root>/**/*.{css,scss,sass}"
  - "<frontend_root>/*tailwind*.{js,ts,cjs}"
  - "<frontend_root>/**/*token*"
  - "<frontend_root>/**/theme*.*"
---
```

`frontend-components.md`:

```yaml
---
description: Component conventions for <framework> frontend at <relative_root> — file structure, prop patterns, naming, and styling integration. Applies when editing JS/TS component files.
paths:
  - "<frontend_root>/src/components/**"
  - "<frontend_root>/components/**"
  - "<frontend_root>/src/ui/**"
---
```

Replace `<frontend_root>` with the relative path from the project root (e.g., `projects/desktop/ui`).
Replace `<framework>` and `<relative_root>` with values from `frontend_analysis.json`.
Write the block as the literal first lines of the file, before any `# Heading`.

**Mermaid pre-write validation:**

Before writing `frontend-data-flow.mmd`, scan the diagram text for known invalid patterns:

- `participant .+ as .+<br/>` — `<br/>` in an `as` alias is not supported; replace with a short plain alias (move extra info into a `note over` block if needed)
- `Note over .+:.*[;]` or arrow message text containing `;` — strip semicolons or replace with a comma / em-dash

Fix in memory before the Write call — do NOT write a broken diagram and fix in a follow-up Write.

### Phase: Update root CLAUDE.md Architecture section

Read CLAUDE.md. Locate `## Architecture` heading. Find existing `### Frontend` subsection inside Architecture (if any).

- **No existing `### Frontend`**: append a new `### Frontend` subsection at the end of the Architecture section (before next `##` heading).
- **Existing `### Frontend`**: replace its body in place with fresh content. Do not touch other subsections or `##` sections.

Content of `### Frontend` subsection:

```markdown
### Frontend

- Stack: <framework-name version> with <styling-model>
- See [.claude/docs/reference-component-creation-template.md](.claude/docs/reference-component-creation-template.md) — prescriptive recipe for creating new components (primary read for component-creation agents)
- Design system tokens: `@.claude/rules/frontend-design-system.md`
- Component conventions: `@.claude/rules/frontend-components.md`
- Architecture overview: [.claude/docs/reference-architecture-frontend.md](.claude/docs/reference-architecture-frontend.md)
- Component inventory: [.claude/docs/reference-component-inventory.md](.claude/docs/reference-component-inventory.md)
- Data-flow diagram: [.claude/sequences/frontend-data-flow.mmd](.claude/sequences/frontend-data-flow.mmd)
```

### Phase: Report

Write report to `.claude/state/reports/create-frontend-docs-<DISPLAY_TS>.md`.

**First-line machine-diff metadata** (per `rules/report-format.md`):

```text
<!-- report: skill=create-frontend-docs ts=<ISO-UTC> wall_clock_sec=<int> frontends=<N> artefacts=<int> stack=<aggregated-per-root> -->
```

Hard rules: prefix literal `<!-- report:`, `key=value` format (not JSON), exact key names (`ts` not `run_ts`, `artefacts` not `artefact_count`).

Per-phase timings REQUIRED: `PREFLIGHT`, `ASSEMBLE`, `CONFIRM`, `WRITE`, `UPDATE_CLAUDE_MD`, `REPORT`.

Body: `## Summary` / `## Phase Timings` / `## Artefacts` (list of written paths + line counts) / `## Next-step Recommendations` (suggest `/update-frontend-docs <area>` for targeted refresh, `/create-docs rule` for project-specific extras).

## What This Skill Does NOT Do

- Run subagents / do analysis — that's `/analyze-frontend`
- Touch source code of the project
- Rewrite the whole project `CLAUDE.md` — only the `### Frontend` subsection under `## Architecture`
- Invent data not present in the JSON — if a field is missing, emit "not observed" in the template
- Validate that the JSON is still accurate for the current code — that's the user's responsibility (run `/analyze-frontend` first if unsure)
