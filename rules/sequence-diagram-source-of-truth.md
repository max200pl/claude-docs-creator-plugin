# Sequence Diagrams Are the Source of Truth for Flow

## Rule

The execution order, branching logic, and actor interactions for any skill or workflow are defined in its `.mmd` sequence diagram. SKILL.md and other docs provide **reference details** (templates, constraints, tables) but never define flow.

## Why

Duplicating flow in both a diagram and prose leads to drift — one gets updated, the other doesn't. A single source of truth eliminates conflicting instructions and makes reordering steps a one-file change.

## Location

Sequence diagrams live in `sequences/` — separate from prose docs in `docs/`.

**Small skill** — single file:

```text
sequences/
  create-docs.mmd
  create-mermaid.mmd
```

**Large skill (100+ lines or 8+ phases)** — split into a folder by phase groups:

```text
sequences/
  init-project/
    index.mmd                  — overview: phases as high-level notes, references parts
    detection-and-discovery.mmd — scaffold + detect stack + discover modules
    generation-and-report.mmd   — analyze + generate docs + settings + report
```

Split rules:

- `index.mmd` is the entry point — shows all phases as collapsed notes, links to part files
- Each part covers 2-4 related phases (group by logical concern, not by count)
- Part filenames describe what phases they contain
- SKILL.md references the folder: `> **Flow:** read all files in \`sequences/init-project/\``

## How to Apply

- **Every skill with ordered phases** must have a companion `.mmd` in `sequences/`
- **SKILL.md** must reference the diagram at the top: `> **Flow:** read \`sequences/<name>.mmd\``
- **SKILL.md sections** provide templates, rules, constraints, and examples — never "do X, then Y, then Z"
- **Section headings** in SKILL.md should match `note` labels in the diagram for easy cross-reference
- **When changing execution order**: edit the `.mmd` file only — do not touch SKILL.md section order
- **When adding a new phase**: add a `note` block in the `.mmd`, then add a matching reference section in SKILL.md

## What Belongs Where

| Content | Where |
| ---- | ---- |
| Execution order, branching, loops | `.mmd` sequence diagram |
| Actor interactions (who calls whom) | `.mmd` sequence diagram |
| Conditional logic (alt/opt/break) | `.mmd` sequence diagram |
| Templates and code examples | `SKILL.md` reference section |
| Tables (markers, patterns, sizes) | `SKILL.md` reference section |
| Constraints (line limits, naming) | `SKILL.md` reference section |
