---
paths:
  - "**/*.md"
  - "**/*.mmd"
  - ".claude/**/*.mmd"
---

# Markdown Style Rules

Based on official specs:

- [CommonMark Spec](https://spec.commonmark.org/)
- [GitHub Flavored Markdown (GFM)](https://github.github.com/gfm/)
- [Markdownlint Rules](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)

## Headings

- One H1 (`#`) per file, at the top
- No skipping levels: `#` → `##` → `###` (never `#` → `###`)
- Blank line before and after every heading
- ATX style only (`# Heading`), not Setext (`Heading\n===`)
- No trailing punctuation in headings (no `# Title.` or `# Title:`)

## Lists

- Blank line before and after every list block
- Unordered: use `-` (not `*` or `+`), consistent throughout file
- Ordered: **number items sequentially** — `1.`, `2.`, `3.` — NOT `1. 1. 1.` auto-increment style
- Indent nested lists with 2 spaces (unordered) or 3 spaces (ordered)
- No empty list items

```markdown
- Item one
- Item two
  - Nested item (2 spaces indent)

1. First
2. Second
3. Third
   1. Nested ordered (3 spaces indent)
   2. Second nested
```

> **Why not `1. 1. 1.`?** markdownlint allows it as auto-numbering (MD029 "one" style), but the raw source reads like a bug ("all items are 1"). Explicit `1. 2. 3.` makes intent clear and lets readers cross-reference specific items by number.

## Indentation & Spacing

- Use spaces, not tabs
- No trailing whitespace at end of lines
- Single blank line between sections (never 2+ consecutive blank lines)
- No blank lines at start or end of file
- End file with exactly one newline (`\n`)

## Code Blocks

- Use fenced blocks with triple backticks (` ``` `), not indented blocks
- Always specify language after opening fence: ` ```js `, ` ```cpp `, ` ```markdown `
- No bare URLs in prose — use `[text](url)` links

## Emphasis & Inline

- Bold: `**bold**` (not `__bold__`)
- Italic: `*italic*` (not `_italic_`)
- Code: single backtick `` `code` `` for inline
- No spaces inside emphasis markers: `**good**` not `** bad **`

## Links & Images

- Prefer `[text](url)` inline links over reference-style `[text][ref]`
- No bare URLs — always wrap: `[https://example.com](https://example.com)`
- Images: `![alt text](path)` — always include alt text

## Tables

- Use pipes `|` and hyphens `-` for tables
- Align header separator: `|---|` minimum 3 hyphens
- Pad cells with spaces for readability

```markdown
| Column A | Column B |
|----------|----------|
| Value 1  | Value 2  |
```

## YAML Frontmatter

- Delimited by `---` on its own line (top and bottom)
- Use kebab-case for field names: `user-invocable`, not `user_invocable`
- Quote strings containing special characters: `description: "Fix: edge case"`
- Boolean values: `true` / `false` (lowercase, no quotes)

```markdown
---
name: my-rule
description: "What this rule does"
---
```

## Mermaid Diagrams

- If a file contains **only one Mermaid diagram** and nothing else, use `.mmd` extension instead of `.md`
- `.mmd` files contain raw Mermaid syntax without ` ```mermaid ` fences
- If a file mixes prose with diagrams, keep `.md` and use fenced ` ```mermaid ` blocks
- See `rules/mermaid-style.md` for detailed Mermaid formatting rules

## File Naming

- Use kebab-case for filenames: `code-style.md`, not `Code_Style.md`
- Exception: `CLAUDE.md`, `SKILL.md`, `MEMORY.md`, `README.md` — uppercase by convention
