---
paths:
  - "**/*.mmd"
  - "**/*.md"
---

# Mermaid Diagram Style Rules

> Reference: read `docs/how-to-create-mermaid.md` for full guide with examples

## Theme

- Always add `%%{init: {'theme': 'neutral'}}%%` as the first line after frontmatter
- Never use `default` theme (light-only) or `dark` theme (dark-only)
- Never hardcode colors in `rect rgb(...)` — they break on the opposite editor theme
- `rgba` alpha channel is ignored by Mermaid in `rect` — do not rely on it

## Grouping

- Use semantic blocks (`critical/end`, `opt/end`, `alt/else/end`, `break/end`) instead of `rect` for visual grouping
- Use `note over A,B: text` for step labels and annotations
- If `rect` is unavoidable, use `rect transparent` for no-background grouping

## Sequence Diagrams

- Declare all participants at the top before any interaction
- Use `participant X as Label` for readable short aliases
- Use `actor` for human participants, `participant` for systems
- Arrows: `->>` solid request, `-->>` dashed response, `-x` lost message
- Use `activate` / `deactivate` for call lifelines
- One logical step per `note` block — keep notes short (under 40 chars per line, use `<br/>` for wrapping)
- `<br/>` is NOT supported in `participant X as Label` aliases — aliases must be a single plain-text line; no HTML tags in `as` labels
- Avoid semicolons (`;`) in `note over` text and arrow message text — Mermaid treats `;` as a statement separator in some renderers

## Flowcharts

- Specify direction: `TD` (top-down) or `LR` (left-right)
- Use standard shapes: `[rectangle]`, `{diamond}`, `([stadium])`, `((circle))`
- Edge labels: `-->|label|` — keep labels under 20 chars
- Group related nodes with `subgraph Title ... end`
- Do not add inline styles (`style nodeId fill:#color`) — breaks theme

## Compatibility (Mermaid 10.x)

- **No nested subgraphs deeper than 2 levels** — `subgraph > subgraph` is max; a third level causes syntax errors in 10.x renderers
- **No `direction` inside subgraphs** — only use direction at the top-level `flowchart TD/LR`; inner `direction TB` breaks in many renderers
- **Links must target nodes, not subgraph IDs** — `A --> B` where B is a node; `A --> SUBGRAPH_ID` fails silently or errors
- **Quote labels with special characters** — use `["label text"]` for labels containing parentheses, colons, slashes, or ampersands
- **Avoid em-dash `—` in node labels** — use `--` or rephrase; some renderers choke on Unicode dashes in flowcharts
- **Test in target renderer** — GitHub, VS Code preview, and Mermaid Live may parse differently; always verify in the renderer your team uses

## General

- Max diagram width: keep under 10 participants / 8 columns to avoid horizontal scroll
- Use `<br/>` for multiline text inside nodes and note blocks (NOT in `participant X as Label` aliases)
- Escape special characters in labels: wrap in quotes if needed (`"label with (parens)"`)

## File Rules

- One diagram per file → `.mmd` extension, no ` ```mermaid ` fences
- Multiple diagrams or prose + diagram → `.md` with fenced blocks
- Filenames: `kebab-case.mmd`
- Frontmatter: `title` field for diagram name (optional)
