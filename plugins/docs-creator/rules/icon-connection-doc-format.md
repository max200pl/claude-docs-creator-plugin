# Icon Connection Doc Format

## Rule

When `/create-frontend-docs` materializes `design_system.icon_pattern` from `frontend-analysis.json`, it MUST write a standalone artefact at `<project_root>/.claude/docs/reference-icon-connection.md` (single-root) or `icon-connection-<root>.md` (multi-root per [`reference-frontend-analysis-schema.md` § File Naming Convention](../docs/reference-frontend-analysis-schema.md#file-naming-convention-canonical)) following the shape below — in addition to the inline section embedded in `reference-component-creation-template.md`.

This standalone doc is the **human-facing reference**: a designer or developer (not an agent) reads it to learn "how do icons work in this codebase?" without parsing the analysis JSON or wading through framework idioms.

> **Schema 1.3+ two-stream protocol:** body driver fields (`connection`, `color_change`, `library_name`, `path_convention`, `wrapper_component`) come from `frontend-analysis.json` `design_system.icon_pattern`. Tail-narrative sections (`Icon examples` table, `Notes` prose) come from scanner's `## Markdown Content` → `### → .../icon-connection-<root>.md` subsection. Older references in this rule to `icon_pattern.examples` / `icon_pattern.notes` describe field VALUES — in 1.3+ those values arrive via the Markdown Content stream, not via JSON.

## Why a standalone doc

The inline section in `component-creation-template.md` is **agent-facing** — terse, machine-readable, optimized for a generator's lookup. A human onboarding to the project needs more: full example code, conventions to follow, the wrapper component's API, and any flagged tech debt.

Two artefacts, one source. Both regenerate from the same `icon_pattern` JSON block — no manual edits.

## Required shape

The file MUST contain the following sections, in this order, with these exact headings. Sections that have no data (per the conditional rules below) are omitted entirely — not stubbed with "n/a".

### Frontmatter (required)

```yaml
---
description: How icons are connected in <project name> — connection method, color-change strategy, naming, and conventions for new components.
generated_by: docs-creator/create-frontend-docs
generated_at: <ISO-UTC timestamp of the run>
source: .claude/state/frontend-analysis.json#design_system.icon_pattern
---
```

`description:` MUST be present — Claude Code uses it for rule discovery. No `paths:` scoping needed: this is a `docs/`, not a `rules/` file, so it does not auto-load.

### H1 — `# Icon Connection — <project name>`

`<project name>` from the project root's directory basename or the value in root `CLAUDE.md` H1 if present.

### `## How icons are connected in this project`

```markdown
**Method:** `<icon_pattern.connection>` — <one-paragraph plain-English explanation of what this means and when it is used in the codebase>.

**Example from code:**

```<lang>
<verbatim copy from icon_pattern.examples[0].path — pick the most representative file; include 5-15 lines around the relevant code>
```
```

If `icon_pattern.examples` is empty, replace the code block with `_No representative example found in code at analysis time._`.

### `## How icon colors change`

```markdown
**Method:** `<icon_pattern.color_change>` — <one-paragraph explanation of the mechanism>.

<If color_change == "none":>
This project does not change icon colors based on hover/active/disabled state. Icons appear in their authored color across all states.

<Else:>

**Hover/active example:**

```css
<verbatim copy from a representative file's CSS — the state pseudo block>
```
```

### `## Icon assets`

```markdown
- **Location:** `<icon_pattern.path_convention>`
- **Naming convention:** <observed naming — kebab-case + state suffixes, PascalCase, etc.>
- **Color tokens:** <list of icon-related design tokens from design_system.color_palette if any token name contains "icon" / "fill" / "stroke", otherwise "none — colors are baked into SVG files">
```

### `## Helper components`

```markdown
<If icon_pattern.wrapper_component.name is not null:>

**`<wrapper_component.name>`** at `<wrapper_component.path>` — <one-line description of what this component does and what props it accepts; if the agent cannot determine the prop shape from code, write "see file for prop API">.

<Else:>

_No wrapper component — icons are used directly._
```

### `## Conventions to follow`

A bulleted list of prescriptive rules derived from the detected pattern. These are what a NEW component MUST do to match the project. Examples (specific items depend on the actual `icon_pattern`):

- "All SVG icon files live in `<path_convention>`; do not co-locate icons with components."
- "Use the project's `<wrapper_component.name>` for any new icon usage; do not write `<img>` directly."
- "For state-driven color change, use `<color_change>` — do not introduce a different mechanism (e.g. CSS filters when the rest of the project uses SVG-swap)."
- "Stick to kebab-case file names with `-default` / `-active` suffixes."

Generate 3-6 bullets. Each bullet is a concrete DO statement, not a principle. Pull verbatim quotes from `icon_pattern.examples` where useful.

### `## Conflicts / tech debt` (conditional)

```markdown
<If icon_pattern.notes is non-empty:>

> ⚠ The detector found a divergence between code and project documentation:
>
> <verbatim icon_pattern.notes content>

This document follows the **code**, not the conflicting rule. Resolution is up to the team — either update the code to match the rule or update the rule to reflect the code. The detector does not auto-fix.

<Else: omit this section entirely.>
```

### `## See also`

```markdown
- [`reference-component-creation-template.md`](./reference-component-creation-template.md) — Icon usage patterns inline section (agent-facing)
- For Sciter projects: `@plugins/component-creator/docs/reference-sciter-icons.md` — full Sciter icon methods reference (connection methods, color-change methods, decision matrix)
- [`frontend-design-system.md`](../rules/frontend-design-system.md) — design tokens that icons may reference
```

For non-Sciter projects, replace the second bullet with a generic library reference (e.g. `lucide-react documentation` URL if `library_name == "lucide-react"`), or omit it.

## Conditional behavior summary

| icon_pattern state | Doc behavior |
| ---- | ---- |
| `connection == null` AND `notes == "no icons detected"` | Write a 1-section minimal doc explaining no icons were detected; suggest running `/docs-creator:update-frontend-docs design-system` after icons are added |
| `wrapper_component.name == null` | "Helper components" section reads `_No wrapper component — icons are used directly._` |
| `notes` is non-empty | Include "Conflicts / tech debt" section verbatim |
| `notes` is empty | Omit "Conflicts / tech debt" section |
| `color_change == "none"` | "How icon colors change" section is the explanatory line; no code example |

## Size target

Single screen for a typical project — roughly 50-120 lines. If the doc would exceed 200 lines, the agent is probably duplicating data from `reference-component-creation-template.md`; tighten.

## What this file is NOT

- Not a Sciter-specific reference (use `reference-sciter-icons.md` for that)
- Not a design-system reference (use `frontend-design-system.md` for tokens)
- Not a tutorial — no "how to add a new icon step by step" instructions; reference docs only

## Enforcement

`create-frontend-docs` SKILL.md has a dedicated phase "Write reference-icon-connection.md" that follows this format. The `doc-reviewer` subagent (when invoked) should verify the file matches this rule on every regeneration.

If a future skill needs to update this doc partially, it MUST use `/update-frontend-docs design-system` rather than hand-editing — the doc is generated, not authored.
