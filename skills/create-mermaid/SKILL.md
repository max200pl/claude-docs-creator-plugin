---
name: create-mermaid
scope: shared
description: "Create a Mermaid diagram (.mmd) for documenting architecture, flows, sequences, or relationships"
user-invocable: true
argument-hint: "<diagram-type> <name> [description]"
---

# Create Mermaid Diagram

> **Flow:** read `sequences/create-mermaid.mmd` — the sequence diagram is the source of truth for execution order
> Style rules: read `rules/mermaid-style.md`
> Reference guide: read `docs/how-to-create-mermaid.md`

Generate a theme-agnostic Mermaid diagram file.

## Usage

`/create-mermaid <diagram-type> <name> [description]`

**Diagram types:**

| Type | Mermaid syntax | Use for |
| ---- | ---- | ---- |
| `sequence` | `sequenceDiagram` | API calls, request flows, skill/agent workflows |
| `flow` | `flowchart TD/LR` | Decision trees, pipelines, CI/CD flows |
| `state` | `stateDiagram-v2` | Lifecycle, status transitions |
| `class` | `classDiagram` | Architecture, module relationships, interfaces |
| `er` | `erDiagram` | Data models, database schemas |

If no type is given, choose the best type based on the description.

## Reference

Detailed instructions for each phase in the sequence diagram.

### Analyze subject

How to choose diagram type:

- Flow or process description → `sequence` or `flow`
- States or lifecycle → `state`
- Structure or relationships → `class` or `er`
- Code reference → read source files first, diagram the real architecture
- Skill or agent reference → read the SKILL.md / agent .md, diagram its workflow

### Generate .mmd file

**Location:**

- Sequence diagrams for skills → `sequences/<name>.mmd`
- Other diagrams → `docs/<name>.mmd`

**Mandatory structure:**

```text
---
title: "Descriptive Title"
---
%%{init: {'theme': 'neutral'}}%%
<diagram-type>
    ...
```

Constraints:

- Always `%%{init: {'theme': 'neutral'}}%%` — never hardcode colors
- Never use `rect rgb(...)` or `rect rgba(...)` — use semantic blocks (`critical`, `opt`, `alt`, `break`) or `note over`
- Declare all participants/classes/entities at the top
- Use short aliases: `participant DB as Database`
- Keep notes under 40 chars per line, use `<br/>` for wrapping
- Max 10 participants / 8 columns to avoid horizontal scroll

### Verify

Checks:

- File is at correct location (`sequences/` for skill flows, `docs/` for others)
- First non-frontmatter line is `%%{init: {'theme': 'neutral'}}%%`
- No `rect rgb` or `rect rgba`
- No hardcoded colors or inline styles

## Output

```text
[CREATED] sequences/auth-flow.mmd — sequence diagram (5 participants, 12 interactions)
[THEME]   neutral (light + dark compatible)
```
