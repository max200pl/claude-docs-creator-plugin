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
| `components` | `component-inventory` | `frontend_roots[*].component_inventory` | `.claude/rules/frontend-components.md` (rules) + `.claude/state/component-registry.json` (SoT — merge per-component entries; preserve lifecycle state) — **1.4: reference-component-inventory.md NO LONGER generated** |
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
/update-frontend-docs --rebuild-schema       # M11 T7: forced full re-scan, migrates schema 1.2 → 1.3 (see Phase: Rebuild Schema below)
/update-frontend-docs --migrate-inventory-to-registry  # M13 T5: one-time migration from 1.3 inventory.md → 1.4 registry-only
```

## `--migrate-inventory-to-registry` mode (M13 T5 — one-time 1.3 → 1.4 migration)

> Replaces deprecated per-root `reference-component-inventory-<root>.md` artefacts with merge into `component-registry.json`.

When to use:

- Project at schema 1.3 has `.claude/docs/reference-component-inventory-<root>.md` files
- Upgrading docs-creator past 0.21.0 (which dropped inventory.md materialization)

Effect:

1. **Locate** all `reference-component-inventory*.md` (or `component-inventory-*.md` for multi-root canonical) files
2. **Parse** the `## Notable components` table per file: extract `Name | Path | Description` columns
3. **Read** existing `component-registry.json`
4. **Merge each row**:
   - Match by `name` (case-sensitive) OR `path` (exact)
   - If existing entry found → UPDATE `description` (preserve lifecycle state — `status`, `figma_*`, `ssim_score`, `created_at`, `last_verified_at`)
   - If no match (new) → ADD with `status: "scanned-only"`, `last_scanned_at: now()`, `created_at: now()`
5. **Rename source** `reference-component-inventory-<root>.md` → `reference-component-inventory-<root>.md.bak.YYYYMMDD` (recovery safety)
6. **Update CLAUDE.md** — remove `Component inventory: [...]` line from `### Frontend` subsection if present
7. **Final report** flags any inventory.md rows that couldn't be merged (e.g. missing path column; ambiguous name match across roots)

Conflicts:

- `--migrate-inventory-to-registry` + `--rebuild-schema` → rebuild covers it (rebuild does fresh scan, populates registry from scratch). Migration only needed if user wants to preserve EXISTING inventory.md descriptions (which `--rebuild-schema` would lose because scanner re-generates descriptions from fresh code observation).

## `--rebuild-schema` mode (M11 T7 migration path)

> Single-command migration from schema 1.2 → 1.3. Re-runs ALL 7 Wave 2 subagents, writes JSON with `schema_version: "1.3"`, regenerates ALL `.md` artefacts using canonical naming + two-stream protocol.

When to use:

- Project's `frontend-analysis.json` has `schema_version: "1.2"` (or older)
- Migrating after upgrading docs-creator past 0.19.0 (which shipped schema 1.3 alignment)
- `validate-claude-docs` flagged drift between current JSON shape and canonical schema 1.3

Effect:

1. **Preflight detects schema mismatch** — if `schema_version != "1.3"`, prints upgrade summary + asks user to confirm `--rebuild-schema`
2. **Re-invokes all 7 Wave 2 subagents** — `tech-stack-profiler`, `architecture-analyzer`, `design-system-scanner`, `component-inventory`, `data-flow-mapper`, `framework-idiom-extractor`, `feature-flow-detector`
3. **Rewrites JSON entirely** — slim YAML from each subagent's Stream 1; `schema_version: "1.3"`; updated `generated.ts` + `plugin_version`
4. **Regenerates ALL artefacts** — applies canonical multi-root naming convention; routes scanner's Markdown Content streams to per-area `.md` files
5. **Updates root CLAUDE.md `### Frontend` subsection** — refreshes import paths to match canonical filenames

Difference from regular run:

- Regular `/update-frontend-docs <area>` re-runs ONE area's subagent + regenerates ITS artefact only
- `--rebuild-schema` is a full forced re-scan; ignores `<area>` arg if both given (warns and proceeds with full rebuild)

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
- `schema_version` < "1.3" → if `--rebuild-schema` flag set → proceed via Phase: Rebuild Schema below. If flag NOT set → warn: "JSON is at schema_version <X>; current toolkit emits schema 1.3. Per-area updates may produce mixed-state JSON. Recommended: run `/docs-creator:update-frontend-docs --rebuild-schema` for full migration. Continue with partial update anyway? [y/N]"
- `schema_version` > "1.3" → stop: "JSON schema_version ahead of this plugin version. Upgrade plugin first."
- `<area>` argument missing or not in the valid list → stop with the valid-area table.
- `--rebuild-schema` AND `<area>` BOTH given → warn "—rebuild-schema overrides area filter; proceeding with full rebuild" → proceed to Phase: Rebuild Schema.

### Phase: Rebuild Schema (M11 T7 migration mode)

Triggered by `--rebuild-schema` flag (or auto-suggested on schema_version mismatch). Steps:

1. **Re-invoke ALL 7 Wave 2 subagents** in parallel — same fan-out as `/analyze-frontend`. Provide each with current `frontend_root`, `stack_profile` (from JSON or fresh tech-stack-profiler), `entry_points`.
2. **Parse subagent outputs** — each emits Stream 1 (slim YAML) + Stream 2 (Markdown Content with `### → <path>` routing).
3. **Rewrite JSON entirely** — replace `frontend_roots[i]` per-block with fresh slim YAML from each subagent. Set:
   - `schema_version: "1.3"`
   - `generated.ts`: now()
   - `generated.plugin_version`: current
   - `generated.skill`: `update-frontend-docs`
   - `generated.previous_refresh`: snapshot of prior `generated.ts` + `plugin_version` + `schema_version` (for drift T3 to use)
4. **Regenerate ALL artefacts** — apply canonical naming convention (single-root vs multi-root prefix rules); route Markdown Content streams per scanner's `### → <path>` H3 routing. Skip artefacts where scanner returned SKIP.
5. **Update root CLAUDE.md `### Frontend` subsection** — refresh `@`-imports + descriptions to match canonical filenames.
6. **Final report** — list every file rewritten + flag any cross-refs the orchestrator could not auto-resolve (e.g. user-added rule references to legacy filenames).

After this phase, skip the regular Re-invoke/Update JSON/Regenerate phases — full rebuild already covered them.

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

### Phase: Compute drift (M11 T3)

Before writing JSON, compute the top-level `drift` block per frontend root. This consolidates 6 previously-scattered drift signals (`architecture.structural_changes`, `design_system.changes_vs_docs`, `component_inventory.new_since_last_doc`, `data_flow.changed_since_last_doc`, `framework_idioms.new_patterns_vs_docs`, `feature_flows.new_features_since_last_doc`) into one structure.

For each frontend root in scope:

1. **Read previous block state** from JSON before overwriting (i.e. snapshot the BLOCK being refreshed: e.g. previous `design_system` block).
2. **Diff against new block state** from this run's subagent output. Per-block diff rules:
   - `architecture`: detect changes to `architecture_pattern`, `top_level_dirs`, `folder_boundary_style` → emit string descriptions
   - `design_system`: detect new tokens (counts changed), new icon-pattern, new styling-patterns fields, mechanism changes → emit string descriptions
   - `component_inventory`: detect new components (counter diff), naming-convention changes → emit string descriptions
   - `data_flow`: detect new state containers, data-fetching pattern change, new auth flow → emit string descriptions
   - `framework_idioms`: detect new patterns_found entries → emit string descriptions
   - `feature_flows`: detect new feature_registry entries (pattern + view diff) → emit string descriptions
3. **Populate `drift` block** on the per-root JSON:
   ```yaml
   drift:
     since_ts: <prev generated.ts>
     since_plugin_version: <prev generated.plugin_version>
     architecture: [<change description strings>]    # [] if no change since prev scan
     design_system: [...]
     component_inventory: [...]
     data_flow: [...]
     framework_idioms: [...]
     feature_flows: [...]
   ```
4. **First-scan exception** — if there is no previous JSON (fresh `/analyze-frontend` or no `generated.previous_refresh` snapshot), emit `drift` with `since_ts: ""`, `since_plugin_version: ""`, all arrays `[]`.

`--rebuild-schema` mode populates `drift` based on the prior whole-block snapshot (one entry per renamed/dropped/added field per block) — useful as a migration changelog visible in the JSON itself.

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
- `components` → regenerate TWO artefacts from `component_inventory` block + scanner Markdown Content streams:
  1. `.claude/rules/frontend-components.md` (+ per-root suffix) — body from scanner's `### → .claude/rules/frontend-components-<root>.md` Markdown Content subsection (RULES content: conventions, prop patterns, file structure, anti-patterns). Prepend frontmatter (description, paths: scoping, naming_conventions block from JSON).
  2. `.claude/state/component-registry.json` (single source of truth — schema 1.4) — MERGE per-component entries from scanner's `### → .claude/state/component-registry.json` Markdown Content subsection. Rules:
     - **New entry** (no `path`/`name` match): ADD with `status: "scanned-only"`, `last_scanned_at: now()`, `created_at: now()`
     - **Existing entry** (matches): UPDATE `name`, `path`, `type`, `description`, `uses[]`, `last_scanned_at: now()`. PRESERVE lifecycle fields (`status` ≠ "scanned-only" preserved; `figma_*`, `ssim_score`, `created_at`, `last_verified_at`, `last_figma_sync_at`).
     - **Was in registry but file missing on current scan**: UPDATE `status: "stale"`. Do NOT delete.
     - Update top-level `generated.last_full_scan_ts: now()` on the registry JSON.

  **1.4 change (M13):** `.claude/docs/reference-component-inventory-<root>.md` is **NO LONGER GENERATED**. Per-component catalog (name, path, type, description, uses) lives ONLY in `component-registry.json`. If an existing legacy `.md` file is detected, warn user and suggest `--migrate-inventory-to-registry`.
- `data-flow` → regenerate `.claude/sequences/frontend-data-flow.mmd` from `data_flow.primary_flow_mermaid`
- `architecture` → regenerate `.claude/docs/reference-architecture-frontend.md` from `tech_stack` + `architecture`; ALSO regenerate `reference-component-creation-template.md` (because styling_model / class_naming in Stack section changed)
- `framework-idioms` → regenerate `reference-component-creation-template.md` (framework idioms are one of its sections)
- `feature-flows` → regenerate `.claude/sequences/features/*.mmd` from `feature_flows.diagram_groups`; ALSO update the `## Feature data flows` section in `reference-component-creation-template.md`
- `template` → regenerate `reference-component-creation-template.md` from current JSON (no subagent ran)

Use the canonical file-naming rules per [`reference-frontend-analysis-schema.md` § File Naming Convention](../../docs/reference-frontend-analysis-schema.md#file-naming-convention-canonical) — same as `/create-frontend-docs`:

- Single-root (`frontend_roots.length == 1`): keep `reference-` prefix in `.claude/docs/` filenames.
- Multi-root (`frontend_roots.length > 1`): **DROP** `reference-` prefix in `.claude/docs/` AND append `-<root-slug>` suffix. Examples: `icon-connection-desktop.md`, `styling-flow-installer.md`, NOT `reference-icon-connection-desktop.md`.
- `.claude/rules/` filenames: append `-<root-slug>` suffix only (no prefix to drop).

When updating per-root files, also rewrite cross-references in artefact bodies to match the target's actual filename (substitute both the file path AND any "See also" links).

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
