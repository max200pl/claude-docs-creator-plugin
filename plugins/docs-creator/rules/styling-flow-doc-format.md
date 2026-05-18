# Styling Flow Doc Format

## Rule

When `/create-frontend-docs` materializes `design_system.styling_patterns` from `frontend-analysis.json`, it MUST write a standalone artefact at `<project_root>/.claude/docs/reference-styling-flow.md` (single-root) or `styling-flow-<root>.md` (multi-root per [`reference-frontend-analysis-schema.md` § File Naming Convention](../docs/reference-frontend-analysis-schema.md#file-naming-convention-canonical)) following the shape below.

This is the **project-specific styling flow** — the 4-step stepper instantiated with the detected project values (preprocessor, variable syntax, mixin syntax, import system, etc.). Component generators (`sciter-create-component` and any future React/Vue adapters) MUST read this artefact FIRST when emitting CSS — the toolkit's framework-specific reference (`reference-sciter-styling.md` etc.) is fallback only.

> **Schema 1.3+ two-stream protocol:** body driver fields (`preprocessor`, `bundler`, `build_mode`, all 4 stepper sub-fields) come from `frontend-analysis.json` `design_system.styling_patterns`. Tail-narrative `Notes` section comes from scanner's `## Markdown Content` → `### → .../styling-flow-<root>.md` → `#### Notes` subsection. References in this rule to `styling_patterns.notes` describe the VALUE — in 1.3+ that value arrives via Markdown Content, not via JSON.

## Why a standalone doc

Toolkit's `reference-sciter-styling.md` documents the **Sciter defaults** (`@mixin name {` no parens, `--var`, BEM, runtime CSS). Real projects vary — SCSS uses `@mixin name() { }` + `@include`, Less uses `.name() { }`, projects with PostCSS may use `var(--name)` with custom-property polyfill, bundler-driven projects import CSS from JS instead of `@import` chains.

This doc captures the **observed project pattern** as substitutions into the stepper template. Generators read it, apply the substitutions, emit correctly-dialected CSS that matches the project's existing code.

Two artefacts, one source: this doc + the styling section embedded in `reference-component-creation-template.md`. Both regenerate from the same `styling_patterns` JSON — no manual edits.

## Required shape

Sections in this order, with these exact headings. Sections that don't apply to the detected preprocessor are omitted, not stubbed with "n/a".

### Frontmatter (required)

```yaml
---
description: Styling flow in <project name> — preprocessor, file layout, scope, naming, and ingredients per the 4-step stepper.
generated_by: docs-creator/create-frontend-docs
generated_at: <ISO-UTC timestamp>
source_json: .claude/state/frontend-analysis.json
schema_version: <version of frontend-analysis schema>
---
```

### Step 0 — Preprocessor & Build Pipeline

Required. One short paragraph + a values table:

```markdown
## Step 0 — Preprocessor & Build Pipeline

This project uses <preprocessor> with <bundler>. Style files use the <build_mode> pipeline.

| Detected | Value |
| ---- | ---- |
| preprocessor | <e.g. "scss"> |
| file_extensions | <list, e.g. `.scss`, `.module.scss`, `.css`> |
| bundler | <e.g. "vite"> |
| build_mode | <e.g. "compile-time-bundled"> |

> **Implication for generator:** new style files use `<dominant file extension>`. Imports resolve at <build|runtime>.
```

### Step 1 — Topology

Required. Section per `import_syntax` detected. Example for SCSS `@use`:

```markdown
## Step 1 — Topology

**File layout:** `<css_file_layout>` — components ship a `<name>.scss` next to `<name>.tsx` (or equivalent).

**Import syntax:** `<import_syntax>` — example:

​```scss
// In a component file:
@use '../tokens';
@use '../typography' as t;

.button { color: tokens.$color-primary; }
.label  { @include t.font-md-medium; }
​```

**Import strategy:** `<import_strategy>` — <one-paragraph explanation per detected value>

**Main entry (if applicable):** `<main_entry path>`. Import order in the entry: <inferred from detected order>.

> **Generator rule:** new component files emit `@use` (or `@import` per detected syntax) for shared modules — never inline `@import` of `tokens.scss` if project uses `@use`. New component CSS is appended to <main_entry> when `import_strategy: "main-entry-aggregate"`; otherwise the component's JS imports its own CSS.
```

Adapt the example block to the detected `import_syntax`:

- `"scss-use"` — show `@use 'name';` + access via `name.$var`
- `"scss-import"` — show `@import 'name';` (legacy)
- `"scss-forward"` — show `@forward 'name';`
- `"css-at-import"` — show `@import 'file.css';`
- `"less-import"` — show Less `@import 'name';`
- `"stylus-import"` — show Stylus `@import 'name'`
- `"bundler-js"` — show JS `import './styles.module.scss';` and/or `import styles from './styles.module.scss'`

### Step 2 — Scope

Required. Per `styleset_usage`:

```markdown
## Step 2 — Scope

**Encapsulation:** `<encapsulation.scope>` — <explanation>.

**Style modules / sets:** `<styleset_usage>` — <example or "not used in this project">.
```

If `styleset_usage != "none"`, include the framework's style-module syntax example (Sciter `@set`, CSS Modules `.module.scss`, styled-components `css\`...\``, etc. — pick by `framework_hint`).

### Step 3 — Naming

Required. Per detected BEM/non-BEM pattern:

```markdown
## Step 3 — Naming

**Block prefix:** `<naming_prefix_pattern>` — e.g. for `Button` component, block name is `.button`.

**Sub-component naming:** `<sub_component_naming>` — sub-components in `<parent>/ui/<sub>.<ext>` use <namespaced "<parent>-<sub>" | chained "<parent>__<sub>"> blocks.

**BEM dialect rules:**
- Elements: `.<block>__<element>`
- Modifiers: `.<block>--<modifier>`
- State compound: `.<block>--<state> .<block>__<element>` (repeat block; don't collapse)

> **Generator rule:** every emitted selector must start with `<block>`. Bare generic selectors (`.icon`, `.label`, `.row`) are forbidden.
```

### Step 4 — Ingredients

Required. Two subsections — Variables and Typography — per detected syntax.

```markdown
## Step 4 — Ingredients

### Variables (`<variable_syntax>`)

Tokens live in: `<token_file path>` — declare new tokens there, never inside component CSS.

Example reference in component CSS:

​```scss
// Project pattern (variable_syntax = scss-dollar):
.button { color: $color-primary; padding: $space-md; }

// Or with @use namespace if scss-use detected:
@use '../tokens';
.button { color: tokens.$color-primary; }
​```

> **Generator rule:** emit `<variable_syntax>` references — not other dialects. New tokens append to `<token_file>` as `<example new token declaration line>`.

### Typography (`<typography_mechanism>` via `<mixin_syntax>`)

Typography lives in: `<typography_file path>`.

Example reference in component CSS:

​```scss
// Project pattern (mixin_syntax = scss-mixin-include):
.label { @include font-md-medium; }

// Or for Sciter (mixin_syntax = sciter-at-mixin):
.label { @font-md-medium; }
​```

> **Generator rule:** typography always via `<mixin invocation syntax>`. Never `font:` shorthand with `var()`/`$var` (silently ignored in Sciter; behaves unexpectedly in some preprocessors). New mixins prompt user before adding to `<typography_file>`.
```

Adapt code-block examples to the detected dialect:

| `variable_syntax` | Token declaration | Token reference |
| ---- | ---- | ---- |
| `"css-custom-properties"` | `--color-primary: #4E4EFF;` (inside `:root`) | `var(--color-primary)` |
| `"scss-dollar"` | `$color-primary: #4E4EFF;` (top-level) | `$color-primary` (or `namespace.$color-primary` if @use) |
| `"less-at"` | `@color-primary: #4E4EFF;` | `@color-primary` |
| `"stylus-equals"` | `color-primary = #4E4EFF` | `color-primary` |

| `mixin_syntax` | Mixin declaration | Mixin invocation |
| ---- | ---- | ---- |
| `"sciter-at-mixin"` | `@mixin font-md-medium { ... }` (no parens) | `@font-md-medium;` |
| `"scss-mixin-include"` | `@mixin font-md-medium() { ... }` | `@include font-md-medium();` |
| `"less-class-mixin"` | `.font-md-medium() { ... }` | `.font-md-medium();` |
| `"sass-placeholder"` | `%font-md-medium { ... }` | `@extend %font-md-medium;` |
| `"stylus-mixin"` | `font-md-medium() { ... }` | `font-md-medium()` |

### Conflicts & Notes (conditional)

Include only if `styling_patterns.notes` is non-empty:

```markdown
## Notes

<verbatim from styling_patterns.notes>
```

### Cross-References (required)

```markdown
## Cross-References

- Toolkit reference (Sciter defaults, fallback): `plugins/component-creator/docs/reference-sciter-styling.md`
- CSS syntax foundation: `plugins/component-creator/docs/reference-sciter-css.md`
- Component creation template: `.claude/docs/reference-component-creation-template.md`
```

## How `sciter-create-component` consumes this doc

Phase 2B reads `.claude/docs/reference-styling-flow.md` FIRST. For each step (Topology / Scope / Naming / Ingredients):

1. If the doc has a value for the relevant field → apply it.
2. If the field is silent or missing → fall back to `plugins/component-creator/docs/reference-sciter-styling.md` (toolkit default).

Header-comment in generated component CSS cites which doc supplied each step's rules:

```css
/* Styling per .claude/docs/reference-styling-flow.md (Step 1-4)
 * Mechanism syntax: plugins/component-creator/docs/reference-sciter-css.md § Style Organization */
```

## Forbidden in this doc

- "n/a" stubs — omit the section if data is missing
- Hand-edits between regenerations (regenerator overwrites)
- Examples that don't match `variable_syntax` / `mixin_syntax` / `import_syntax` of the detected project
- Generic Sciter examples when project preprocessor is SCSS/Less/Stylus
- Cross-refs to research reports in toolkit `.claude/docs/` (those are toolkit-internal — user-facing doc should not point at them)

## Regeneration

This doc regenerates on every `/create-frontend-docs` and `/update-frontend-docs design-system` run. Manual edits are lost.
