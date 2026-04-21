---
description: "Conventions for docs/ — filename prefixes, size tiers per doc type, when to split a large doc, when to promote prose into a scoped rule."
paths:
  - "docs/**"
---

# `docs/` Folder Structure

The `docs/` directory holds **reference prose** — tutorials, how-tos, checklists, research reports, and reference tables. It is NOT a place for Claude-executed instructions (those go in `CLAUDE.md` or `rules/`). Unlike `rules/`, files here do NOT auto-load; they are read on demand by skills, linked from other docs, or referenced by the user.

## Note on Officiality

`docs/` is a toolkit convention (`claude-docs-creator`), not a Claude Code spec folder. The official directory list at <https://code.claude.com/docs/en/claude-directory> does not mention it. Treat content here as project-specific reference material — not as instructions Claude must follow on every session.

## Filename Prefix Conventions

Every file in `docs/` must start with one of these prefixes. The prefix signals type and sorts the listing:

| Prefix | Purpose | Example |
| ---- | ---- | ---- |
| `tutorial-` | Step-by-step human walkthrough, ELI5 / beginner-friendly | `tutorial-getting-started.md` |
| `how-to-` | Recipe / pattern reference for a specific problem | `how-to-slim-claude-md.md` |
| `checklist-` | Done-criteria for a workflow | `checklist-component-done.md` |
| `research-` | `/research` output — web findings with sources | `research-flow-testing.md` |
| `reference-` | Reference tables, indexes, link catalogues | `reference-keybindings.md` |
| `mapping-` | Translations between two domains (design → code, etc.) | `mapping-figma-to-fsd.md` |
| `tutorial-<topic>/` | Multi-part tutorial — folder with `index.md` + `part-*.md` | `tutorial-hooks/index.md` |

Files without a prefix are allowed only for toolkit-authored meta-docs (`milestones.md`, `testing-checklist.md`, `two-claude-workflow.md`) — these predate the convention and are grandfathered.

Never use these as prefixes: `draft-`, `old-`, `deprecated-`, `temp-`. Delete instead.

## Size Tiers Per Type

Applies to each file in `docs/`. Soft = nudge, Warn = split candidate, Hard = must split.

| Type | Soft `[OK]` ≤ | Warn `[WARN]` ≤ | Hard `[ERR]` > |
| ---- | ---- | ---- | ---- |
| `tutorial-` | 400 | 600 | 600 |
| `how-to-` | 200 | 350 | 350 |
| `checklist-` | 150 | 250 | 250 |
| `research-` | 600 | 1000 | 1000 |
| `reference-` | 300 | 500 | 500 |
| `mapping-` | 200 | 400 | 400 |
| unprefixed / grandfathered | 400 | 600 | 600 |

## When to Split a Large Doc

A file at `[WARN]` should be split soon; at `[ERR]` must be split before any other edit.

| Symptom | Split strategy |
| ---- | ---- |
| Tutorial covers 3+ distinct workflows | Multi-part folder: `tutorial-X/index.md` + `tutorial-X/part-setup.md` + `tutorial-X/part-usage.md` |
| How-to mixes "how to do X" and "how to do Y" | Two files: `how-to-X.md` + `how-to-Y.md` |
| Research report covers multiple sub-topics | One master `research-<topic>.md` with a "See also" list, plus `research-<topic>-<subtopic>.md` per deep dive |
| Checklist has 4+ phase sections | Split by phase: `checklist-<topic>-pre.md`, `checklist-<topic>-post.md` |
| Reference has multiple indexes | Split by index type: `reference-commands.md` + `reference-keybindings.md` |

After splitting, update every referrer — run `grep -rn 'old-filename.md' .claude/ CLAUDE.md` and patch each hit.

## When to Promote Prose into a Scoped Rule

Move content from `docs/` → `rules/` when:

- Claude should apply it automatically when editing matching files (not just when the user asks)
- You'd want it loaded into context even without an explicit `Read`
- It is a CONSTRAINT (do / don't) rather than a PROCEDURE (how to)

Keep content in `docs/` when:

- Intended for humans to read and follow manually
- A skill `Read`s it on demand (e.g. `> Reference: read docs/how-to-X.md`)
- It is narrative / explanation, not terse directive

A good signal: if the file currently begins with "## Rule" or "## Do / Don't" — promote to `rules/`.

## Nesting and Directory Depth

`docs/` is flat by default. Every new file lives at `docs/<prefix>-<name>.md`. A subdirectory is allowed ONLY in these cases:

| Allowed subdir | Purpose | Example |
| ---- | ---- | ---- |
| `docs/tutorial-<topic>/` | Multi-part tutorial — file grew past 600 lines OR covers 3+ distinct workflows | `docs/tutorial-hooks/index.md` + `docs/tutorial-hooks/part-setup.md` |
| `docs/research-<topic>/` | Multi-file research — one master + sub-topic files | `docs/research-flow-testing/index.md` + `docs/research-flow-testing/inspect-ai.md` |
| `docs/<area>/` | Per-area reference bundle when ≥5 related docs share a prefix | `docs/mapping/figma-to-fsd.md` + `docs/mapping/design-to-code.md` |

Depth limits:

- **Max 2 levels:** `docs/<name>.md` (1 level) or `docs/<area>/<name>.md` (2 levels). Never `docs/a/b/c.md`.
- **Each subdir MUST contain an `index.md`** that summarizes what's inside and links to every sibling in that folder.
- **Flat > Nested.** Don't create a subdir "just to organize." Create one only when flat naming becomes unreadable (5+ files with the same prefix, or a single topic truly needs a master + parts).
- **Don't mirror code tree.** `docs/` is not `src/`. Naming by audience and intent (`tutorial-`, `how-to-`) beats naming by code area.

When in doubt — keep it flat. Renaming `docs/x.md` is one `git mv`; moving a nested tree is many.

## Required Shape of a Doc File

Every doc file must have:

1. **Frontmatter** (optional but recommended for `tutorial-`, `research-`):

   ```yaml
   ---
   topic: <short-topic>
   level: beginner | intermediate | reference
   date: YYYY-MM-DD
   estimated-time: <minutes>
   ---
   ```

2. **H1** matching the prefix and topic: `# Tutorial: <Topic>` / `# How To: <Topic>` / `# Checklist: <Topic>` / `# Research: <Topic>`
3. **Intro paragraph** — under 4 sentences, states what the reader gets
4. **Body sections** with `##` headings; never skip heading levels
5. **Related / Next Steps** section at the end, linking siblings

Optional but recommended:

- **Prerequisites** block (especially for tutorials)
- **Verify** or **Success Criteria** block (for tutorials, how-tos, checklists)
- **Common Mistakes** table (for tutorials, how-tos)

## Cross-References Between Docs

Use relative links for siblings: `[text](./sibling.md)` — never absolute filesystem paths, never anchor-fragment links between docs (Claude navigates poorly across anchors).

If a doc is referenced from three or more other docs → consider promoting to an index entry in `/menu` so it's discoverable without traversal.

## What NOT to Put in `docs/`

- Rule-style terse directives ("MUST", "NEVER") — those go in `rules/`
- SKILL.md phase definitions — those go in `skills/<name>/`
- Mermaid diagrams that are the source of truth for a skill's flow — those go in `sequences/`
- Auto-generated transcripts, logs, or scratch files — these don't belong in git
- Per-user personal notes — those go in `CLAUDE.local.md` (gitignored)
