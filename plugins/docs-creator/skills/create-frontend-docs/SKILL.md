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
> Skip policy: `rules/artefact-skip-policy.md` — when to create vs omit files on SKIP
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
- `.claude/docs/reference-icon-connection.md` — icon connection method, color-change strategy, naming convention (from `design_system.icon_pattern`)
- `.claude/docs/reference-styling-flow.md` — project-specific 4-step styling stepper (Topology / Scope / Naming / Ingredients) with detected preprocessor + variable + mixin syntax (from `design_system.styling_patterns`)
- `.claude/sequences/frontend-data-flow.mmd` — state + API flow Mermaid diagram (top-level, from `data-flow-mapper`)
- `.claude/sequences/features/<pattern>.mmd` — one diagram per detected feature-flow pattern (from `feature-flow-detector`; omitted if `feature_flows` is null in JSON)

**Surgical CLAUDE.md update:**

- Root `CLAUDE.md` — adds a `### Frontend` subsection under `## Architecture` with `@`-imports to all new artefacts. Replaces existing `### Frontend` subsection if present; does not touch other sections.

**Registry:**

- `.claude/state/component-registry.json` — component registry; single source of truth; must be committed to git (add `!.claude/state/component-registry.json` to project `.gitignore` exceptions)

**Operational:**

- `.claude/state/reports/create-frontend-docs-<ts>.md` — run report (gitignored)

## Usage

```text
/create-frontend-docs                  # materialize latest analysis as docs
/create-frontend-docs --force-rerun    # force analyze-frontend first, then create (chain)
/create-frontend-docs --only components # regenerate only frontend-components.md + reference-component-inventory.md
```

`--only` accepts the same areas as `/analyze-frontend`: `design-system`, `components`, `data-flow`, `architecture`, `framework-idioms`, `feature-flows`, `all`. It filters WRITES — it doesn't re-run analysis. (For re-analyzing + rewriting a single area, use `/update-frontend-docs <area>`.)

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
- `schema_version` field not matching the skill's expected (currently `1.2` — bumped in Phase 3.6 to add `design_system.icon_pattern`) → stop: "Analysis schema version mismatch. Re-run `/analyze-frontend` to regenerate."
- `generated.ts` older than 30 days → warn but proceed unless `--force-rerun`.
- `frontend_roots` empty → stop: "Analysis has no frontend roots. Re-run `/analyze-frontend`."

`--force-rerun` flag → invoke `/analyze-frontend` first (via skill chain), then proceed with the fresh JSON. Not auto-invoke; just prompts user to do it if they pass the flag.

### Phase: Assemble primary template

Build `.claude/docs/reference-component-creation-template.md` from JSON per the section-feeding map in [rules/component-creation-template-format.md](../../rules/component-creation-template-format.md). Concrete mapping:

| Template section | JSON source (schema 1.3 canonical) |
| ---- | ---- |
| File layout | `architecture.top_level_dirs` + `component_inventory.canonical_skeleton` (path) + `component_inventory.folder_structure` |
| Imports block | Excerpt first N import lines from file referenced by `component_inventory.canonical_skeleton` |
| Props declaration | `component_inventory.naming_conventions.component_file` (for file-naming) + observed prop pattern from scanner's Markdown Content (was `primary_prop_type`, `ref_forwarding`, `naming_convention` singular in legacy — all dropped/moved in 1.3) |
| Styling model | `tech_stack.styling_model` — render as prescriptive paragraph |
| Class naming | `tech_stack.class_naming` + `tech_stack.custom_class_prefix` |
| State and data wiring | `data_flow.state_containers`, `data_flow.data_fetching_pattern`, `data_flow.form_library`, `data_flow.auth_flow` (canonical names — were `data_fetching`, `forms`, `authentication` in legacy) |
| Event handling | From scanner's Markdown Content `### → frontend-components-<root>.md` RULES file (was `component_inventory.event_handler_convention` in legacy) |
| Accessibility patterns | From scanner's Markdown Content RULES section, OR "None systematically observed" (was `component_inventory.a11y_observations` in legacy) |
| Test and story conventions | `component_inventory.test_colocation`, `storybook_present`, `storybook_coverage_pct` |
| Design-token usage | `design_system.mechanism` + 1-2 examples from `design_system.color_palette` / `typography` |
| Icon usage patterns (inline) | `design_system.icon_pattern.*` — see [rules/component-creation-template-format.md](../../rules/component-creation-template-format.md) `## Icon usage patterns` section spec |
| Icon connection reference (standalone artefact) | `design_system.icon_pattern.*` — also writes `.claude/docs/reference-icon-connection.md` per [rules/icon-connection-doc-format.md](../../rules/icon-connection-doc-format.md) (see new phase below) |
| Framework-specific idioms | `framework_idioms.body_markdown` (verbatim — already formatted by the subagent) |
| Canonical skeleton | `component_inventory.canonical_skeleton_excerpt` verbatim |
| Anti-patterns | Union of Notes flagged as anti-patterns across all subagents |
| Cross-references | Auto-generated `@`-links to the 5 reference files |

If a JSON section is `null` or SKIP (subagent returned SKIP during analysis), the corresponding template section becomes a single-line "not observed in this project" explanation — not omitted entirely.

### Phase: Write artefacts

**File-naming convention** — canonical rule per [`reference-frontend-analysis-schema.md` § File Naming Convention](../../docs/reference-frontend-analysis-schema.md#file-naming-convention-canonical):

| `frontend_roots.length` | `.claude/docs/` filenames | `.claude/rules/` filenames |
| ---- | ---- | ---- |
| **1** (single-root) | `reference-<name>.md` (KEEP `reference-` prefix) | `<name>.md` (no prefix; standard) |
| **> 1** (multi-root) | `<name>-<root-slug>.md` (**DROP** `reference-` prefix; append `-<root-slug>` suffix) | `<name>-<root-slug>.md` (just suffix) |

`<root-slug>` is the last directory component of `frontend_roots[i].relative` (e.g. `projects/desktop/ui` → `desktop`; `res` → `res`; `apps/web` → `web`).

**Examples:**

| Artefact | Single-root | Multi-root (3 roots: desktop, notifier, installer) |
| ---- | ---- | ---- |
| `.claude/docs/reference-component-creation-template.md` | as-is | `component-creation-template-desktop.md`, `component-creation-template-notifier.md`, `component-creation-template-installer.md` |
| `.claude/docs/reference-architecture-frontend.md` | as-is | `architecture-frontend-desktop.md`, ...notifier, ...installer |
| `.claude/docs/reference-component-inventory.md` | as-is | `component-inventory-desktop.md`, ... |
| `.claude/docs/reference-icon-connection.md` | as-is | `icon-connection-desktop.md`, ... |
| `.claude/docs/reference-styling-flow.md` | as-is | `styling-flow-desktop.md`, ... |
| `.claude/rules/frontend-design-system.md` | as-is | `frontend-design-system-desktop.md`, ... |
| `.claude/rules/frontend-components.md` | as-is | `frontend-components-desktop.md`, ... |

**Rationale for prefix-drop in multi-root:** noisy filenames like `reference-component-creation-template-desktop.md` are visually heavy; dropping `reference-` keeps multi-root filenames short and signals "this is a per-root variant". This matches user-intended convention observed in pc_cleaner and similar multi-frontend projects.

**Cross-reference substitution:** when an artefact body contains a link to another artefact (e.g. "See `reference-component-creation-template.md`"), substitute the link target with the correct filename for THIS project's root count + root-slug.

**Paths-scoping for generated rules — exact frontmatter blocks to prepend:**

> **REQUIRED:** Both rule files MUST have `description:` in frontmatter. Claude Code uses `description:` to display the rule in `/rules` and to explain when it applies. A rule file written without `description:` is a bug — do not skip it.

`frontend-design-system.md`:

```yaml
---
description: Design system tokens and styling conventions for <framework> frontend at <relative_root>. Applies when editing CSS/SCSS/styling files in the frontend root.
paths:
  - "<frontend_root>/**/*.{css,scss,sass}"
  - "<frontend_root>/*tailwind*.{js,ts,cjs}"
  - "<frontend_root>/**/*token*"
  - "<frontend_root>/**/theme*.*"
token_file: <value from design_system.token_file in JSON — relative path from project root, or "none">
typography_file: <value from design_system.typography_file in JSON — relative path from project root, or "none">
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

Replace `<frontend_root>` with the relative path from the project root (e.g., `apps/web`).
Replace `<framework>` and `<relative_root>` with values from `frontend_analysis.json`.
Write the block as the literal first lines of the file, before any `# Heading`.

**`reference-component-inventory.md` frontmatter** — prepend this block before `# Heading`:

```yaml
---
generated-by: create-frontend-docs
frontend-root: <relative_root>
naming_conventions:
  component_file: <value from component_inventory.naming_conventions.component_file>
  css_file: <value from component_inventory.naming_conventions.css_file>
  class_name: <value from component_inventory.naming_conventions.class_name>
  directory: <value from component_inventory.naming_conventions.directory>
---
```

If `component_inventory.naming_conventions` is null, omit the `naming_conventions:` key and write `naming_conventions: null` as a single line.

**Pre-write self-check:** Before calling Write for either rule file, verify the string you are about to write starts with `---` and contains `description:`. If it does not — construct the frontmatter now from the JSON values, prepend it, then write. Do not proceed without `description:`.

**Mermaid pre-write validation:**

Before writing `frontend-data-flow.mmd`, scan the diagram text for known invalid patterns:

- `participant .+ as .+<br/>` — `<br/>` in an `as` alias is not supported; replace with a short plain alias (move extra info into a `note over` block if needed)
- `Note over .+:.*[;]` or arrow message text containing `;` — strip semicolons or replace with a comma / em-dash

Fix in memory before the Write call — do NOT write a broken diagram and fix in a follow-up Write.

### Phase: Write component-registry.json

Read `component_inventory.components` list from `frontend-analysis.json`. For each component entry produce a registry record:

```json
{
  "name": "<PascalCase component name>",
  "type": "primitive | feature | local",
  "layer": "<fsd layer or folder slug — e.g. shared/ui, entities, features>",
  "path": "<relative path from project root to component file>",
  "figma_node_id": null,
  "figma_file_key": null,
  "figma_connected": false,
  "uses": [],
  "parent": null,
  "created_at": "<ISO-UTC timestamp of this run>",
  "last_verified_at": null,
  "last_figma_sync_at": null,
  "figma_last_modified": null,
  "ssim_score": null,
  "status": "unverified"
}
```

**Type classification:**
- `type: "primitive"` — component lives in `shared/ui`, `components/ui`, `common/`, `design-system/`, or has a generic UI name (Button, Input, Modal, Badge, etc.)
- `type: "feature"` — component lives in `features/`, `entities/`, or has a domain-specific name
- `type: "local"` — component lives inside another component's directory (child/nested)

**Output files:**
1. Write `.claude/state/component-registry.json` — single source of truth, no markdown mirror.

Merge logic if file already exists: preserve records with `figma_node_id` set; overwrite `status: "unverified"` records with fresh data. Never delete records with `figma_connected: true`.

Also ensure project `.gitignore` has exception: `!.claude/state/component-registry.json` (registry must be version-controlled to preserve Figma connections across sessions).

### Phase: Write reference-icon-connection.md

Materialize the icon connection standalone doc — the human-facing record of how icons work in this project. Always written when `design_system.icon_pattern` exists in JSON (i.e. always, since the field is required as of Phase 3.6).

**Sources (TWO-STREAM protocol since schema 1.3+):**

- **JSON driver fields:** `design_system.icon_pattern.{connection, color_change, library_name, path_convention, wrapper_component}` from `frontend-analysis.json` — render per `rules/icon-connection-doc-format.md` body shape
- **Scanner Markdown Content tail:** parse `design-system-scanner` output's `## Markdown Content` section → find `### → .claude/docs/reference-icon-connection-<root>.md` H3 → extract content between this H3 and the next `### →` (or end of `## Markdown Content`). This contains `#### Icon examples` table + `#### Notes` prose. Append AFTER JSON-driven sections.

**Target:** `<project_root>/.claude/docs/reference-icon-connection.md`

**Format spec:** [plugins/docs-creator/rules/icon-connection-doc-format.md](../../rules/icon-connection-doc-format.md) — follow its section order, headings, and conditional blocks exactly. Do NOT invent sections; do NOT omit required sections.

**Conditional behavior:**

- `icon_pattern.connection == null` AND scanner Markdown Content subsection is absent → write a minimal doc with one section explaining "No icons detected in this project — when icons are added later, run `/docs-creator:update-frontend-docs design-system` to refresh." Do not fabricate examples.
- `icon_pattern.wrapper_component.name == null` → omit the "Helper components" section content; render only `_No wrapper component — icons are used directly._`
- Scanner emitted `#### Notes` inside the `### → reference-icon-connection` subsection → include the prose verbatim under the "Conflicts / tech debt" or "Notes" heading; otherwise omit that section entirely.
- Scanner emitted `#### Icon examples` table → include it as the "Icon examples" section; otherwise omit.

**Cross-references:** the generated doc MUST include a "See also" footer linking back to:
- `@.claude/docs/reference-component-creation-template.md` (Icon usage patterns inline section)
- For Sciter projects: `@plugins/component-creator/docs/reference-sciter-icons.md` (the methods reference)

**File-naming:** same convention as `reference-component-creation-template.md` — plain name for single root, `-<root-slug>` suffix for multi-root.

### Phase: Write reference-styling-flow.md

Materialize the **project-specific styling flow** — the 4-step stepper (Topology / Scope / Naming / Ingredients) instantiated with project values (preprocessor, variable syntax, mixin syntax, etc.). Always written when `design_system.styling_patterns` exists in JSON (required as of Phase 3.9, schema v0.17.0+).

**Sources (TWO-STREAM protocol since schema 1.3+):**

- **JSON driver fields:** `design_system.styling_patterns.*` (preprocessor, bundler, build_mode, all 4 stepper fields) from `frontend-analysis.json` — render per `rules/styling-flow-doc-format.md` body shape with per-preprocessor dialect templating
- **Scanner Markdown Content tail:** parse `design-system-scanner` output's `## Markdown Content` section → find `### → .claude/docs/reference-styling-flow-<root>.md` H3 → extract `#### Notes` content. Append AFTER JSON-driven stepper sections.

**Target:** `<project_root>/.claude/docs/reference-styling-flow.md`

**Format spec:** [plugins/docs-creator/rules/styling-flow-doc-format.md](../../rules/styling-flow-doc-format.md) — follow its section order, headings, and per-preprocessor templating exactly. Each code-example block adapts to `variable_syntax` / `mixin_syntax` / `import_syntax`.

**Conditional behavior:**

- `styling_patterns.preprocessor == "none"` AND `framework_hint == "Sciter"` → use Sciter dialect throughout (Sciter `@mixin name {` no parens, `--var`, `style-set:` if `styleset_usage != "none"`).
- `styling_patterns.preprocessor == "scss"` / `"sass"` → use SCSS dialect (`@mixin name() {}` + `@include`, `$var`, `@use`/`@import`).
- `styling_patterns.preprocessor == "less"` → use Less dialect (`.mixin() {}`, `@var`).
- `styling_patterns.preprocessor == "stylus"` → use Stylus dialect (block mixins, `name = value`).
- `styling_patterns.preprocessor == "postcss"` → use vanilla CSS dialect (`--var`); note PostCSS-specific plugins in Step 0.
- `styling_patterns.notes` non-empty → include "Conflicts & Notes" section verbatim from `notes`; otherwise omit that section.

**Cross-references:** the generated doc MUST include a "Cross-References" footer linking to:
- For Sciter projects: `plugins/component-creator/docs/reference-sciter-styling.md` (toolkit base, fallback)
- `plugins/component-creator/docs/reference-sciter-css.md` (CSS syntax foundation)
- `.claude/docs/reference-component-creation-template.md`

**Consumer contract:** this doc is read FIRST by `sciter-create-component` (and any future component-creator adapter) during Phase 2B. Toolkit's `reference-sciter-styling.md` is fallback only when this doc is silent on a specific aspect.

**File-naming:** same convention as `reference-component-creation-template.md` — plain name for single root, `-<root-slug>` suffix for multi-root.

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
- Icon connection: [.claude/docs/reference-icon-connection.md](.claude/docs/reference-icon-connection.md)
- Styling flow: [.claude/docs/reference-styling-flow.md](.claude/docs/reference-styling-flow.md)
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
