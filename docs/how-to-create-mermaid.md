# How to Create Mermaid Diagrams

> Official docs: [Mermaid Syntax Reference](https://mermaid.js.org/intro/syntax-reference.html)

## File Format

- One diagram per file → `.mmd` extension, raw Mermaid syntax, no fences
- Multiple diagrams or prose + diagram → `.md` extension with ` ```mermaid ` fenced blocks
- Filenames: `kebab-case.mmd` (e.g. `create-docs.mmd`, `auth-flow.mmd`)
- Sequence diagrams go in `sequences/`, other diagrams in `docs/`

## Theme-Agnostic Diagrams

Diagrams must render correctly on **both light and dark** editor themes. Hardcoded colors break on the opposite theme.

### Use the neutral theme

Always start `.mmd` files with:

```text
%%{init: {'theme': 'neutral'}}%%
```

The `neutral` theme uses grayscale tones that work on any background. Avoid `default` (light-only) and `dark` (dark-only).

### Never hardcode colors in rect

`rect rgb(40, 40, 55)` looks fine on dark, broken on light. `rect rgb(230, 230, 240)` looks fine on light, invisible on dark. Also: `rgba` alpha channel is **ignored** by Mermaid in `rect` blocks — this is a known limitation.

**Instead of colored `rect`, use Mermaid's semantic blocks** that are styled by the theme automatically:

| Instead of | Use | Why |
| ---- | ---- | ---- |
| `rect rgb(...)` for grouping | `note over A,B: Step label` | Styled by theme |
| `rect` for critical path | `critical ... end` | Semantic + themed |
| `rect` for optional flow | `opt ... end` | Semantic + themed |
| `rect` for error handling | `break ... end` | Semantic + themed |

### If you must use rect

Use `rect transparent` for a no-background grouping box (only for visual separation, no color).

## Diagram Types Cheat Sheet

### Sequence Diagram

```text
%%{init: {'theme': 'neutral'}}%%
sequenceDiagram
    actor User
    participant S as Service
    participant DB as Database

    User->>S: Request
    activate S
    S->>DB: Query
    DB-->>S: Result
    S-->>User: Response
    deactivate S
```

**Key rules:**

- Declare all participants at the top
- Use `participant X as Label` for readable aliases
- Use `actor` for human participants
- Arrows: `->>` (solid, request), `-->>` (dashed, response)
- Use `activate` / `deactivate` for lifelines
- Use `note over A,B: text` for annotations spanning participants
- Group logic with `alt/else/end`, `opt/end`, `critical/end`, `break/end`
- Avoid `rect` — use semantic blocks instead

### Flowchart

```text
%%{init: {'theme': 'neutral'}}%%
flowchart TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Action A]
    B -->|No| D[Action B]
    C --> E[End]
    D --> E
```

**Key rules:**

- `TD` (top-down) or `LR` (left-right) for direction
- Node shapes: `[rectangle]`, `{diamond}`, `([stadium])`, `((circle))`, `[[subroutine]]`
- Edge labels: `-->|label|`
- Use `subgraph` for grouping, not styling

### State Diagram

```text
%%{init: {'theme': 'neutral'}}%%
stateDiagram-v2
    [*] --> Idle
    Idle --> Processing : start
    Processing --> Done : complete
    Processing --> Error : fail
    Error --> Idle : retry
    Done --> [*]
```

### Class Diagram

```text
%%{init: {'theme': 'neutral'}}%%
classDiagram
    class IKernel {
        <<interface>>
        +Start()
        +Stop()
    }
    class AppKernel {
        -modules : vector
        +Start()
        +Stop()
        +GetModule(name) IModule
    }
    IKernel <|-- AppKernel
```

### Entity Relationship

```text
%%{init: {'theme': 'neutral'}}%%
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : "is in"
```

## Frontmatter in .mmd

`.mmd` files support YAML frontmatter for title:

```text
---
title: "Diagram Title"
---
%%{init: {'theme': 'neutral'}}%%
sequenceDiagram
    ...
```

The `title` renders above the diagram in supported renderers (GitHub, VS Code Mermaid Preview).

## Supported Renderers

| Renderer | .mmd support | Theme from | Notes |
| ---- | ---- | ---- | ---- |
| GitHub | Yes (in `.md` fences) | GitHub theme | `.mmd` files render as raw text |
| VS Code (Markdown Preview Mermaid) | Yes | Init directive | Requires extension |
| VS Code (Mermaid Editor) | Yes | Init directive | Native `.mmd` support |
| GitLab | Yes (in `.md` fences) | Init directive | `.mmd` not rendered inline |
| Obsidian | Yes (in `.md` fences) | App theme | Override with init directive |

**Tip:** GitHub does not render `.mmd` files natively. If GitHub rendering matters, also embed the diagram in a `.md` file or README.
