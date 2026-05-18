---
description: "Canonical schema for frontend-analysis.json — the contract every analyze-frontend subagent emits and every downstream consumer reads. Schema version 1.3."
---

# `frontend-analysis.json` — Canonical Schema 1.4

> **1.4 change (M13):** `component-registry.json` becomes the single source of truth for the per-component catalog. `reference-component-inventory.md` is no longer materialized. The `component_inventory` block here keeps only structural counters + naming convention + `registry_path` pointer — full per-component data (name, path, type, description, uses[], lifecycle) lives in `.claude/state/component-registry.json`.

## Schema version history

| Version | Date | Changes |
| ---- | ---- | ---- |
| 1.0 | initial | Baseline analyze-frontend output |
| 1.1 | 2026-04-21 | Phase A gap fields (token_file, naming_conventions, styling_system) |
| 1.2 | 2026-05-12 | Phase 3.6 — `design_system.icon_pattern` added |
| 1.3 | 2026-05-18 | M11 closure — all 8 blocks aligned, canonical field names, two-stream scanner output, top-level `drift` block, canonical multi-root naming |
| 1.4 | 2026-05-18 | M13 — `component-registry.json` is single source of truth for components; `reference-component-inventory.md` dropped; `component_inventory` block slimmed to counters + naming + `registry_path` pointer |

> Source of truth for the JSON shape produced by `/docs-creator:analyze-frontend` and `/docs-creator:update-frontend-docs <area>`.
> Subagents (`tech-stack-profiler`, `architecture-analyzer`, `design-system-scanner`, `component-inventory`, `data-flow-mapper`, `framework-idiom-extractor`, `feature-flow-detector`) MUST emit the YAML shape defined here.
> Downstream consumers (`create-frontend-docs`, `update-frontend-docs`, `sciter-create-component`, future generators) read fields defined here.
> Schema evolved in M11: see [`research-frontend-analysis-schema-drift.md`](../../../.claude/docs/research-frontend-analysis-schema-drift.md) for the categorization analysis that drove this contract.

## Design Principles

1. **JSON = driver schema, .md = catalog.** JSON holds only what generators NEED to make a decision (enums, paths, ints, small lists). Tables, prose, examples, narrative live in `.claude/rules/` (RULES) or `.claude/docs/` (NARRATIVE).
2. **Same shape across all projects.** Required fields are required regardless of stack. Optional fields have explicit emit-conditions.
3. **Per-root nesting.** Each frontend root gets its own copy of the per-root blocks under `frontend_roots[N]`.
4. **One concept, one name.** No singular/plural duplicates (`naming_convention` AND `naming_conventions`). No synonyms (`organizing_principle` AND `architecture_pattern`). Canonical names defined here; aliases dropped.
5. **Drift is consolidated.** Every change-tracking signal lives in the top-level `drift` block per root. No scattered `new_since_last_doc` / `changed_since_last_doc` / `structural_changes` across blocks.
6. **Two-output protocol.** Each subagent emits TWO streams in one scan pass: slim JSON (this schema) + rich markdown (catalog/rules content for downstream `.md` write). `create-frontend-docs` consumes both.

## Top-Level Structure

```yaml
schema_version: "1.4"
generated:
  plugin_version: <string>          # e.g. "0.21.0"
  skill: <string>                   # "analyze-frontend" | "update-frontend-docs"
  ts: <ISO-8601 UTC>                # scan start
  wall_clock_sec: <int>             # scan duration
  frontends_analyzed: <int>         # length of frontend_roots
  only_filter: <string>             # "" | "design-system" | "components" | ... (for partial refresh)
  previous_refresh:                 # OPTIONAL — present after at least one update-frontend-docs run
    ts: <ISO-8601 UTC>
    plugin_version: <string>
    schema_version: <string>
frontend_roots:
  - <FrontendRoot>                  # see below
```

## Per-Root Structure

```yaml
relative: <string>                  # e.g. "projects/desktop/ui" — relative to repo root
path: <string>                      # absolute path on the scan machine
detector: <DetectorBlock>           # block 1
tech_stack: <TechStackBlock>        # block 2
architecture: <ArchitectureBlock>   # block 3
design_system: <DesignSystemBlock>  # block 4
component_inventory: <ComponentInventoryBlock>  # block 5
data_flow: <DataFlowBlock>          # block 6
framework_idioms: <FrameworkIdiomsBlock>  # block 7
feature_flows: <FeatureFlowsBlock>  # block 8
drift: <DriftBlock>                 # NEW in 1.3 — top-level per root
```

**REQUIRED:** all 9 blocks per root. Empty blocks emit `{}` (not null/missing). Drift block emits empty arrays when no changes since last scan.

---

## Block 1 — `detector`

> Wave 1 output from `frontend-detector` agent. Establishes frontend identity before fan-out.

```yaml
detector:
  framework: <enum>                 # REQUIRED — "react" | "vue" | "svelte" | "angular" | "solid" | "sciter" | "vanilla" | "unknown"
  framework_version: <string>       # REQUIRED — "" if unknown
  package_manager: <enum>           # REQUIRED — "npm" | "yarn" | "pnpm" | "bun" | "none" (Sciter)
  entry_points: [<path>]            # REQUIRED — list of entry files (HTML/JS roots)
  confidence: <enum>                # REQUIRED — "high" | "medium" | "low"
```

**Forbidden:** narrative `note` / `notes` fields. If commentary about detection is needed, append to scanner markdown stream → `.claude/docs/reference-architecture-frontend.md`.

---

## Block 2 — `tech_stack`

> From `tech-stack-profiler` agent.

```yaml
tech_stack:
  # Core stack — REQUIRED
  framework: <string>               # canonical short name, e.g. "Sciter.js Reactor", "Next.js 14"
  framework_version: <string>       # "" if unknown
  language: <enum>                  # "typescript" | "javascript" | "jsx" | "tsx" | "mixed"
  ts_strictness: <enum>             # "strict" | "non-strict" | "any" | "n/a"
  package_manager: <enum>           # match detector.package_manager
  bundler: <enum>                   # "vite" | "webpack" | "rollup" | "parcel" | "next" | "esbuild" | "runtime" | "none"
  rendering_mode: <enum>            # "spa" | "ssr" | "ssg" | "hybrid" | "runtime" (Sciter)
  routing: <string>                 # detected router name, "none", or "custom"

  # Styling — REQUIRED
  styling_model: <enum>             # "css-modules" | "scss" | "tailwind" | "styled-components" | "emotion" | "vanilla-extract" | "css-in-js" | "plain-css" | "mixed"
  styling_system: <enum>            # "tailwind-config" | "scss-variables" | "css-variables" | "mui-theme" | "chakra-theme" | "design-tokens" | "ad-hoc" | "none"
  class_naming: <enum>              # "bem" | "pascal-case" | "kebab-case" | "css-modules" | "utility-first" | "mixed"
  custom_class_prefix: <string>     # "" if no prefix; else the dominant prefix

  # Data + state — REQUIRED
  state_management: <string>        # "react-context" | "redux" | "zustand" | "mobx" | "pinia" | "ngrx" | "vuex" | "sciter-element" | "none"
  data_fetching: <string>           # "fetch" | "axios" | "tanstack-query" | "rtk-query" | "apollo" | "swr" | "trpc" | "none"

  # UI library — REQUIRED
  ui_library: <string>              # "mui" | "antd" | "chakra" | "mantine" | "radix" | "shadcn-ui" | "headless-ui" | "none"

  # Testing/linting — REQUIRED
  testing: <string>                 # "vitest" | "jest" | "playwright" | "cypress" | "none"
  linting: <string>                 # "eslint" | "biome" | "prettier" | "none"
```

**Forbidden in JSON:** `notes` field (arrays of strings — these are RULES, route to `.claude/rules/frontend-tech-stack.md`).

---

## Block 3 — `architecture`

> From `architecture-analyzer` agent. Layer organization, routing style, code splitting, layout composition.

```yaml
architecture:
  # Required
  architecture_pattern: <string>     # canonical name was 'organizing_principle' in legacy
                                     # e.g. "feature-sliced-design", "atomic-design", "by-domain", "by-layer", "flat", "custom"
  folder_boundary_style: <enum>      # canonical name was 'folder_boundaries' in legacy
                                     # "strict-fsd" | "loose-feature" | "by-type" | "flat" | "mixed"
  layout_composition: <string>       # short prose: e.g. "Caption + AsidePanel + Content"
  routing_style: <enum>              # "file-based" | "config-based" | "imperative" | "static" | "router-lib"
  code_splitting: <enum>             # "route-based" | "component-based" | "manual" | "none"
  ssr_client_boundary: <enum>        # canonical name was 'ssr_boundaries' in legacy
                                     # "no-ssr" | "use-client" | "directive-based" | "page-level" | "n/a-sciter"
  top_level_dirs: [<string>]         # list of layer dirs at root, e.g. ["app", "widgets", "pages", "shared"]
  public_exports: <enum>             # "index-barrel" | "explicit-imports" | "no-barrel" — useful for FSD detection
  window_size: <string>              # OPTIONAL — for fixed-window apps (Sciter installer dialogs). "" if not applicable
                                     # e.g. "700×460dip", "fixed-390dip-width"
                                     # NOTE: canonical name. Legacy emitted 'window_system' (likely typo). Use 'window_size'.
```

**Forbidden in JSON:**

- `notes` field (was array-of-bullet-rules like `"FSD import rule: layer may only import from below"`) → RULES, route to `.claude/rules/frontend-architecture.md`
- `structural_changes` field → DRIFT, route to top-level `drift.architecture`
- `entry_chain` field (was PC-only narrative description) → NARRATIVE, route to `.claude/docs/reference-architecture-frontend.md`

---

## Block 4 — `design_system`

> From `design-system-scanner` agent. The most catalog-heavy block historically; M11 slims it dramatically.

```yaml
design_system:
  # File paths — REQUIRED
  source_of_truth: <path>            # primary token definition file
  token_file: <path>                 # token declarations live here (often == source_of_truth)
  typography_file: <path>            # typography mixin/scale source; "none" if none

  # Top-level mechanism — REQUIRED
  mechanism: <enum>                  # "css-variables" | "scss-variables" | "less-variables" | "stylus-variables" |
                                     # "tailwind-theme" | "mui-theme" | "design-tokens-json" | "mixed" | "none"
  has_token_system: <bool>           # any structured token mechanism present?
  dark_mode: <enum>                  # "class-based" | "media-query" | "attribute-based" | "context-based" | "none"
  component_skinning: <enum>         # "className" | "sx" | "styled" | "apply" | "mixed"

  # Schema-only summaries — REQUIRED
  color_palette:
    neutral_steps: <int>             # number of named neutral colors (0 if none)
                                     # NOTE: brand[] / semantic[] LISTS belong in .md, not JSON
  typography:
    families: [<string>]             # list of font-family names (small, driver)
    scale_steps: <int>               # number of font-size scale entries (0 if none)
  spacing:
    scale_type: <enum>               # "4dip-multiples" | "8dip-multiples" | "ad-hoc" | "geometric" | "custom"
    steps: <int>                     # number of spacing scale entries (0 if none)
  breakpoints: [<string>]            # list of named breakpoints, [] if fixed-window
  radius: <string>                   # single representative radius or "varies"
  icon_system: <string>              # "none" | "library-name" | "custom-svg" | "@image-map"

  # Icon pattern (Phase 3.6 — schema 1.2) — REQUIRED
  icon_pattern:
    connection: <enum>               # see plugins/docs-creator/docs/reference-icon-patterns.md
    color_change: <enum>             # see same
    library_name: <string>           # "none" or library name
    path_convention: <string>        # e.g. "__DIR__ + 'img/<name>.svg'"
    wrapper_component:
      name: <string>                 # "" if none
      path: <path>                   # "" if none
    # NOTE: examples[] (list of file paths) and notes (prose) belong in .md, not JSON

  # Styling patterns (Phase 3.9 — preprocessor-aware) — REQUIRED
  styling_patterns:
    preprocessor: <enum>             # "none" | "scss" | "sass" | "less" | "stylus" | "postcss"
    file_extensions: [<string>]      # observed style file extensions
    bundler: <enum>                  # match tech_stack.bundler OR "runtime" if no build step
    build_mode: <enum>               # "runtime" | "compile-time-bundled" | "extracted"
    css_file_layout: <enum>          # "co-located" | "centralized" | "mixed"
    import_syntax: <enum>            # "css-at-import" | "scss-use" | "scss-import" | "scss-forward" | "less-import" | "stylus-import" | "bundler-js" | "mixed"
    import_strategy: <enum>          # "main-entry-aggregate" | "per-component-inline" | "bundler-js-driven" | "mixed"
    main_entry: <path>               # only if import_strategy == "main-entry-aggregate"; else "" or null
    styleset_usage: <enum>           # Sciter @set or framework style-modules — "none" | "occasional" | "primary"
    encapsulation:
      scope: <enum>                  # "global" | "prefixed-class" | "data-attribute"
      naming_prefix_pattern: <string>  # e.g. "<component-name>"
      sub_component_naming: <enum>   # "namespaced" | "chained" | "none"
    variable_syntax: <enum>          # "css-custom-properties" | "scss-dollar" | "less-at" | "stylus-equals" | "mixed"
    mixin_syntax: <enum>             # "sciter-at-mixin" | "scss-mixin-include" | "less-class-mixin" | "sass-placeholder" | "stylus-mixin" | "none"
    typography_mechanism: <enum>     # "mixin" | "css-class" | "inline" | "mixed"
```

**Forbidden in JSON (was emitted previously; MOVE to .md outputs):**

- `color_palette.brand`, `color_palette.semantic` — color tables, route to `.claude/rules/frontend-design-system-<root>.md`
- `colors`, `primary_color`, `background_color` (GameBooster extras) — color tables, route to .md
- `shadows`, `z_index`, `radii_dip` (replaced by single `radius` enum) — catalog, route to .md
- `css_variables_found`, `scss_partials_found`, `typography_scale_found` — file lists, route to .md
- `token_source` — duplicate of `token_file`, drop
- `mechanism_detail`, `dark_mode_strategy`, `theme_system` — duplicates, drop
- `secondary_sources` — narrative, drop
- `notes` (prose) — route to `.claude/rules/frontend-design-system-<root>.md` Notes section
- `icon_pattern.examples`, `icon_pattern.notes` — route to `.claude/docs/reference-icon-connection-<root>.md`
- `styling_patterns.notes` — route to `.claude/docs/reference-styling-flow-<root>.md`
- `changes_vs_docs` — DRIFT, route to top-level `drift.design_system`

---

## Block 5 — `component_inventory`

> From `component-inventory` agent. Component classification + naming conventions.

```yaml
component_inventory:
  # Required — structural metadata + naming convention only
  # 1.4: per-component catalog (name, path, type, description, uses[]) lives in registry — see registry_path below
  total_components: <int>            # canonical name was 'total_components_found' in legacy
  folder_structure: <enum>           # "co-located" | "by-type" | "flat" | "mixed"
  naming_conventions:                # full object — REQUIRED
    component_file: <enum>           # "PascalCase" | "kebab-case" | "snake_case"
    css_file: <enum>                 # same enum
    class_name: <enum>               # same enum
    directory: <enum>                # same enum
  has_storybook: <bool>
  has_figma_code_connect: <bool>
  has_preview_files: <bool>          # e.g. Sciter `.preview.js` files
  primitives_count: <int>            # leaf components count
  pages_count: <int>                 # route-level views count (0 if no routing)
  widgets_count: <int>               # widget/feature components count (0 if not applicable)
  layouts_count: <int>               # layout components count (0 if not applicable)
  figma_code_connect_count: <int>    # 0 if has_figma_code_connect == false

  # 1.4: pointer to single source of truth for component catalog
  registry_path: <string>            # ".claude/state/component-registry.json" (relative to project root)
                                     # canonical_skeleton (representative file) now derivable from registry —
                                     # query first entry with status: "managed" OR type: "primitive"
```

**Forbidden in JSON (1.4):**

- `canonical_skeleton` — DROPPED in 1.4 (was in 1.3). The "representative component" is now derived on-demand from `component-registry.json` (query first entry with `status: "managed"` OR `type: "primitive"`)
- `components` (Sc-only enum), `feature_areas`, `feature_views`, `leaf_components`, `sub_views`, `shared_primitives_source` (GB-only classifications), `shared_components`, `view_components` (PC-only lists) — **MOVED to `component-registry.json`** as per-entry `description` field + `type` classification. NO longer materialized into `reference-component-inventory-<root>.md` (that artefact is dropped in 1.4)
- `naming_convention` (singular) — DUPLICATE of `naming_conventions.component_file`, dropped (1.3)
- `ui_library` — DUPLICATE of `tech_stack.ui_library`, dropped (1.3)
- `new_since_last_doc` — DRIFT, route to `drift.component_inventory` (1.3)

### 1.4 migration — `reference-component-inventory-<root>.md`

**This artefact is no longer materialized.** Replaced by:

1. **`component-registry.json`** (single source of truth) — per-component catalog with name, path, type, description, uses[], lifecycle state (figma_connected, ssim_score, status). See `## Component Registry Schema` section in this doc.
2. **`.claude/rules/frontend-components-<root>.md`** — conventions, prop patterns, file-structure rules (already exists; component-inventory agent's Markdown Content stream routes RULES content here).

Existing projects with legacy `reference-component-inventory-<root>.md`: see Migration Guide § 1.3 → 1.4 below. One-command migration via `/docs-creator:update-frontend-docs --migrate-inventory-to-registry`.

---

## Block 6 — `data_flow`

> From `data-flow-mapper` agent. State + API + auth flow.

```yaml
data_flow:
  # Required
  state_containers: [<string>]       # list of detected state container names, [] if none
  cross_view_sharing: <enum>         # "context" | "redux-store" | "url-state" | "local-only" | "global-singleton" | "none"
  data_fetching_pattern: <enum>      # "tanstack-query" | "rtk-query" | "swr" | "raw-fetch" | "axios-direct" | "trpc" | "graphql-client" | "none"
  caching: <enum>                    # canonical name was 'caching_strategy' in legacy
                                     # "query-cache" | "swr-cache" | "manual" | "browser-cache" | "none"
  api_style: <enum>                  # "rest" | "graphql" | "rpc" | "trpc" | "websocket" | "mixed" | "none"
  async_protocol: <enum>             # "http" | "websocket" | "sse" | "polling" | "none"
  has_http: <bool>
  has_websocket: <bool>              # canonical (was 'websocket' in PC — drop alias)
  realtime: <enum>                   # "none" | "polling" | "websocket" | "sse" | "long-polling"
  auth_flow: <string>                # "oauth" | "jwt" | "session" | "basic" | "custom" | "none"
  form_library: <string>             # "react-hook-form" | "formik" | "native" | "none"
  primary_patterns: [<string>]       # list of detected dataflow patterns, e.g. ["fetch-on-mount", "subscribe-on-mount"]
```

**Forbidden in JSON:**

- `body_markdown` (PC-only prose blob) — NARRATIVE, route to `.claude/docs/reference-data-flow-<root>.md` or comment in sequence diagram
- `mermaid_diagram` — full Mermaid source duplicates `.claude/sequences/frontend-data-flow-<root>.mmd`, drop
- `changed_since_last_doc` — DRIFT, route to `drift.data_flow`
- `websocket` field — DUPLICATE of `has_websocket`, drop

---

## Block 7 — `framework_idioms`

> From `framework-idiom-extractor` agent. Idiom classification + pattern detection.

```yaml
framework_idioms:
  # Required
  base_framework: <string>           # canonical name was 'framework_name' in PC
                                     # e.g. "React 19", "Sciter Reactor", "Vue 3 Composition API"
  framework_type: <enum>             # canonical name was 'framework_classification' in PC
                                     # "industry-standard" | "custom-in-house" | "embedded-runtime" | "hybrid"
  classification_confidence: <enum>  # canonical name was 'confidence' in PC
                                     # "high" | "medium" | "low"
  base_classes: [<string>]           # detected base class names — REQUIRED (empty list ok)
                                     # e.g. ["Element", "Reactor"] for Sciter; "React.Component" for class React
  patterns_found: [<string>]         # canonical pattern names detected (enum-ish list)
                                     # e.g. ["hooks", "class-components", "render-props"]
  canonical_skeleton_source: <path>  # representative component for the framework idiom
```

**Forbidden in JSON:**

- `body_markdown` — NARRATIVE, route to `.claude/docs/reference-framework-idioms-<root>.md`
- `anti_patterns` (array of "do not do" patterns) — RULES, route to `.claude/rules/frontend-anti-patterns.md`
- `mandatory_patterns`, `optional_patterns` (arrays of pattern descriptions) — RULES, route to `.claude/rules/frontend-components.md`
- `base_class_decision_rules` (Sc-only array of rules) — RULES, route to `.claude/rules/frontend-components.md`
- `source_files_scanned` — provenance, may be appended to `generated` block but not in this section
- `new_patterns_vs_docs` — DRIFT, route to `drift.framework_idioms`

---

## Block 8 — `feature_flows`

> From `feature-flow-detector` agent. User-facing feature classification.

```yaml
feature_flows:
  # Required
  total_features: <int>
  pattern_distribution: <object>     # canonical name was 'patterns' in PC
                                     # map of pattern-name → count
                                     # e.g. {"scan-loop": 3, "query-display": 5, "dashboard": 2}
  feature_registry: [<FeatureEntry>] # list of {view, pattern, summary} — see below
```

```yaml
FeatureEntry:
  view: <string>                     # component name (e.g. "ScanPage")
  pattern: <enum>                    # see plugins/docs-creator/agents/feature-flow-detector.md for the 6 canonical patterns
  summary: <string>                  # ONE LINE summary, ≤ 80 chars
                                     # NOTE: previous schema used 'description' (often multi-line prose). Renamed + truncated.
```

**Forbidden in JSON:**

- `note` (prose blob) — NARRATIVE, route to `.claude/docs/reference-feature-flows-<root>.md` or sequence-diagram comment
- `new_features_since_last_doc` — DRIFT, route to `drift.feature_flows`
- `feature_registry[].description` longer than 80 chars — truncate to `summary` field

---

## Block 9 — `drift` (NEW in 1.3)

> Per-root change-tracking. Consolidates all change signals previously scattered across blocks. Empty arrays when no changes since last scan.

```yaml
drift:
  since_ts: <ISO-8601 UTC>           # timestamp of previous scan (from previous_refresh)
  since_plugin_version: <string>     # plugin version of previous scan
  # Per-block change lists — REQUIRED, [] if no change
  architecture: [<string>]           # e.g. ["Added new layer: 'features'", "Moved widgets to /components"]
  design_system: [<string>]          # e.g. ["Added 3 new color tokens", "Changed primary radius 4→6"]
  component_inventory: [<string>]    # e.g. ["12 new components", "Renamed Sidebar → AsidePanel"]
  data_flow: [<string>]              # e.g. ["Added Grand Scan → Ada Chatbot flow"]
  framework_idioms: [<string>]       # e.g. ["New pattern: render-props observed in 3 components"]
  feature_flows: [<string>]          # e.g. ["3 new features since last doc"]
```

**Population rule:** populated only by `/docs-creator:update-frontend-docs <area>` skill (which compares previous scan vs current scan and emits diff). Fresh `/analyze-frontend` runs emit `drift: { since_ts: "", since_plugin_version: "", architecture: [], design_system: [], ... }`.

---

## Component Registry Schema (1.4 — single source of truth)

> Schema 1.4 (M13) — `component-registry.json` is the canonical per-component catalog. Lives at `<project_root>/.claude/state/component-registry.json`. Read by component-creator skills + `/status` + `/analyze-frontend` (for merge).

```yaml
# .claude/state/component-registry.json
{
  "schema_version": "1.0",                        # registry schema (independent of analysis schema)
  "generated": {
    "ts": "<ISO-UTC>",                            # last write
    "last_full_scan_ts": "<ISO-UTC>",             # last /analyze-frontend merge
    "plugin_version": "<X.Y.Z>"
  },
  "components": [
    {
      // Identity — REQUIRED
      "name": "<ComponentName>",                  // PascalCase typically
      "path": "<relative-from-project-root>",     // e.g. "src/components/Button/Button.tsx"
      "type": "primitive" | "feature" | "local",  // classification
      "description": "<≤200 chars one-liner>",    // 1.4 NEW — was in inventory.md table

      // Composition — REQUIRED
      "uses": ["<dep-name>", ...],                // dependency graph; [] if leaf
      "parent": "<ParentName>" | null,            // for type:local — host component

      // Lifecycle state — REQUIRED, managed by component-creator
      "status": "scanned-only" | "managed" | "stale" | "done" | "pending",
      "created_at": "<ISO-UTC>",                  // first registry entry
      "last_verified_at": "<ISO-UTC>" | null,     // last /update-component or /create-component success
      "last_scanned_at": "<ISO-UTC>" | null,      // 1.4 NEW — last /analyze-frontend touch

      // Figma — OPTIONAL
      "figma_node_id": "<id>" | null,
      "figma_file_key": "<key>" | null,
      "figma_connected": <bool>,
      "figma_last_modified": "<ISO-UTC>" | null,
      "last_figma_sync_at": "<ISO-UTC>" | null,   // last /sync-registry call

      // Visual verification — OPTIONAL (component-creator only)
      "ssim_score": <float 0-1> | null            // last visual verification
    }
  ]
}
```

### Status enum

| Value | Meaning |
| ---- | ---- |
| `"scanned-only"` | Found on disk by `/analyze-frontend`; not yet managed by component-creator (no Figma metadata, no SSIM run) |
| `"managed"` | Created by `/create-component` or `/update-component` — full lifecycle tracked. May lack Figma metadata if user opted out. |
| `"pending"` | Created but verification incomplete (e.g. SSIM run failed; or initial scaffold pending tweaks) |
| `"done"` | Verified, SSIM ≥ threshold, Figma Code Connect published |
| `"stale"` | Was in registry, but file no longer exists on disk (caught by `/validate-registry` or last scan) |

### Merge rules during `/analyze-frontend`

When `component-inventory` agent emits per-component entries via Markdown Content (T3):

| Scenario | Action |
| ---- | ---- |
| Entry NEW (not in registry) | ADD with `status: "scanned-only"`, `last_scanned_at: now()`, `created_at: now()` |
| Entry EXISTS (matches by `path` or by `name+type`) | UPDATE `name`, `path`, `type`, `description`, `uses[]`, `last_scanned_at: now()` — PRESERVE lifecycle state (`status`, `figma_*`, `ssim_score`, `created_at`, `last_verified_at`, `last_figma_sync_at`) |
| Entry was in registry but file gone | UPDATE `status: "stale"` (do not delete — user may be mid-refactor) |
| Conflict (e.g. registry has different `type` than scanner detected) | Trust SCANNER for type/description; preserve everything else. Flag in `drift.component_inventory`. |

### Registry vs analysis JSON — separation of concerns

| | `component-registry.json` | `frontend-analysis.json` `component_inventory` |
| ---- | ---- | ---- |
| **What** | Per-component catalog + lifecycle | Aggregate stats + naming conventions |
| **Size** | Grows with N components (~200 bytes/entry) | Fixed ~500 bytes/block, regardless of component count |
| **Mutation cadence** | Continuous (every component-creator op) | Refreshed on `/analyze-frontend` / `/update-frontend-docs` |
| **Source of truth for** | Component identity + state | Project-level component conventions |
| **Audience** | Machine (component-creator + /status) | Machine + Markdown materialization |

## Migration from Schema 1.2 → 1.3

Projects with schema 1.2 JSON gracefully degrade — generators tolerant of missing renamed-canonical fields by checking aliases:

| Canonical name (1.3) | Legacy alias(es) (1.2) — read but warn |
| ---- | ---- |
| `architecture_pattern` | `organizing_principle` |
| `folder_boundary_style` | `folder_boundaries` |
| `ssr_client_boundary` | `ssr_boundaries` |
| `window_size` | `window_system` |
| `total_components` | `total_components_found` |
| `canonical_skeleton` | `canonical_skeleton_file` |
| `caching` | `caching_strategy` |
| `has_websocket` | `websocket` |
| `base_framework` | `framework_name` |
| `framework_type` | `framework_classification` |
| `classification_confidence` | `confidence` |
| `pattern_distribution` | `patterns` |
| `radius` | `radii_dip` |
| `naming_conventions.<sub>` | `naming_convention` (singular dropped — was lossy summary) |

**Forced rebuild:** `/docs-creator:update-frontend-docs --rebuild-schema` re-runs scan with 1.3-emitting subagents. Required for downstream consumers that don't implement alias fallback.

## Migration from Schema 1.3 → 1.4 (M13)

Single breaking change: `reference-component-inventory-<root>.md` artefact is **dropped**. Per-component catalog moves to `component-registry.json`.

| Concern | 1.3 location | 1.4 location |
| ---- | ---- | ---- |
| Per-component name, path, type | inventory.md table + registry.json | **registry.json only** |
| Per-component description | inventory.md table (prose column) | **registry.json `description` field** (new) |
| Conventions, prop patterns, file structure | inventory.md sections | `.claude/rules/frontend-components-<root>.md` (already exists; no change) |
| Counter stats (total_components, primitives_count, etc.) | analysis JSON `component_inventory` block | **unchanged** (still in analysis JSON) |
| `canonical_skeleton` (representative file path) | analysis JSON `component_inventory.canonical_skeleton` | **derived from registry**: query first entry with `status: "managed"` OR `type: "primitive"` |

### Migration command

```text
/docs-creator:update-frontend-docs --migrate-inventory-to-registry
```

Effect:

1. For each existing `reference-component-inventory-<root>.md`: parse "Notable components" table; extract `name`, `path`, `description` per row
2. Merge into `component-registry.json`:
   - If entry with same `name` (or `path`) exists → UPDATE description (preserve lifecycle state)
   - If new → ADD with `status: "scanned-only"`, `last_scanned_at: now()`
3. Rename `reference-component-inventory-<root>.md` → `reference-component-inventory-<root>.md.bak` (recover safety)
4. Run `/analyze-frontend` once to refresh `component_inventory` block (drops `canonical_skeleton` field, adds `registry_path`)
5. Final report flags any inventory.md descriptions that couldn't be migrated (e.g. ambiguous component name)

### Forced rebuild path

`/docs-creator:update-frontend-docs --rebuild-schema` (from M11 T7) also handles 1.3 → 1.4:

- All 7 subagents re-invoked; component-inventory agent emits to registry.json instead of inventory.md
- Existing inventory.md files left in place but flagged as deprecated; manual delete recommended after verification
- `schema_version: "1.4"` written to refreshed JSON

### Why not auto-delete inventory.md?

The .md file may contain user-authored notes outside the auto-generated `## Notable components` table. Preserve `.bak` so user can copy any unique content into registry or rules.

## File Naming Convention (CANONICAL)

> Resolves the multi-root naming ambiguity surfaced in M11 T10. Single source of truth — every skill that materializes per-root artefacts MUST follow this.

### Single-root project (`frontend_roots.length == 1`)

All shipped artefacts use the `reference-` prefix in `.claude/docs/`:

| Artefact | Filename |
| ---- | ---- |
| Component-creation template | `.claude/docs/reference-component-creation-template.md` |
| Architecture | `.claude/docs/reference-architecture-frontend.md` |
| Component inventory | `.claude/docs/reference-component-inventory.md` |
| Icon connection | `.claude/docs/reference-icon-connection.md` |
| Styling flow | `.claude/docs/reference-styling-flow.md` |
| Design-system rules | `.claude/rules/frontend-design-system.md` |
| Frontend-components rules | `.claude/rules/frontend-components.md` |

### Multi-root project (`frontend_roots.length > 1`)

The `reference-` prefix is **DROPPED** in `.claude/docs/`, and a `-<root-slug>` suffix is appended. `<root-slug>` is the last directory of `frontend_roots[i].relative` (e.g. `projects/desktop/ui` → `desktop`; `res` → `res`).

| Artefact | Single-root filename | Multi-root filename (per root) |
| ---- | ---- | ---- |
| Component-creation template | `reference-component-creation-template.md` | `component-creation-template-<root>.md` |
| Architecture | `reference-architecture-frontend.md` | `architecture-frontend-<root>.md` |
| Component inventory | `reference-component-inventory.md` | `component-inventory-<root>.md` |
| Icon connection | `reference-icon-connection.md` | `icon-connection-<root>.md` |
| Styling flow | `reference-styling-flow.md` | `styling-flow-<root>.md` |
| Design-system rules | `frontend-design-system.md` | `frontend-design-system-<root>.md` |
| Frontend-components rules | `frontend-components.md` | `frontend-components-<root>.md` |

**Rationale:** users with monorepo / multi-app projects don't want every doc to read `reference-...-multi-root-app.md` (noisy). Dropping `reference-` keeps multi-root filenames short. `.claude/rules/` files don't have the prefix to begin with, so multi-root just adds the suffix.

### Substitution rule for scanner output

Scanner subagents emit `### → <path>` H3 routing headers with `<root>` placeholder in paths (e.g. `### → .claude/docs/reference-icon-connection-<root>.md`). Orchestrators (`create-frontend-docs`, `update-frontend-docs`) MUST apply this substitution:

1. If single-root project: drop the `<root>` placeholder and any preceding `-`, keep `reference-` prefix → `reference-icon-connection.md`
2. If multi-root project: substitute `<root>` with the root-slug AND drop the `reference-` prefix in `.claude/docs/` paths → `icon-connection-<root-slug>.md`

For `.claude/rules/` paths: substitute `<root>` with root-slug only (no prefix dropping needed); single-root drops the placeholder.

### Cross-reference rule

When one shipped artefact links to another (e.g. `reference-icon-connection.md` mentions `reference-component-creation-template.md` in "See also"), the link MUST resolve to the correct filename for the target project's root count. Orchestrators apply substitution to BOTH the target file path AND any cross-refs the artefact body contains.

## Subagent Output Protocol

Each scanner subagent emits **two streams** in a single scan pass:

1. **Structured YAML** — slim JSON fragment conforming to this schema. Goes into `frontend-analysis.json` at the appropriate per-root block.
2. **Markdown content** — rich catalog + rules + narrative. `create-frontend-docs` Phase: Assemble routes this to:
   - `.claude/rules/frontend-<area>-<root>.md` for RULES content (anti_patterns, mandatory_patterns, notes-as-bullet-rules, design-system-conventions)
   - `.claude/docs/reference-<area>-<root>.md` for NARRATIVE content (color tables, icon catalogs, body_markdown, component lists with descriptions, framework-idiom prose)

Each subagent's SKILL/agent .md defines BOTH outputs.

## Validation

`/docs-creator:validate-claude-docs` checks at schema 1.3:

- All 9 per-root blocks present (even if empty)
- All REQUIRED fields per block present
- No forbidden fields present (legacy `body_markdown`, `notes` prose, removed catalog fields)
- All cross-refs between blocks consistent (`detector.framework == tech_stack.framework`, `data_flow.has_websocket == (tech_stack.async_protocol == "websocket")`, etc.)
- `drift` block present even on first scan (empty arrays)

## Cross-References

- [`research-frontend-analysis-schema-drift.md`](../../../.claude/docs/research-frontend-analysis-schema-drift.md) — categorization analysis that drove this schema (toolkit-internal)
- [`reference-icon-patterns.md`](reference-icon-patterns.md) — `icon_pattern.connection` / `color_change` enums (Phase 3.6+)
- [`reference-sciter-styling.md`](../../component-creator/docs/reference-sciter-styling.md) — Sciter-specific `styling_patterns` reference
- [`milestones.md` M11](../../../.claude/docs/milestones.md#m11--slim-json--schema-catalog-separation) — milestone tracking this schema rewrite
