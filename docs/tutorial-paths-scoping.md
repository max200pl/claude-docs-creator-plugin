---
topic: paths-scoping
level: reference
date: 2026-04-20
estimated-time: 5
---

# Tutorial: `paths:` Scoping Cheatsheet

Quick reference for the `paths:` frontmatter field that makes a rule conditional. Reader should already know what a rule is.

## Syntax

```markdown
---
description: "One-line purpose of the rule."
paths:
  - "glob-1"
  - "glob-2"
---

# Rule Body
```

Without `paths:` → rule loads every session (global). With `paths:` → rule loads only when Claude reads a file matching any glob.

## Common Patterns

| Intent | Glob | Matches |
| ---- | ---- | ---- |
| All files under a dir | `src/**` | recursive, any extension |
| One extension in a tree | `src/**/*.ts` | only `.ts` under `src/` |
| Multiple extensions | `src/**/*.{ts,tsx}` | brace-expansion supported |
| Single directory depth | `src/*` | immediate children only |
| A specific file | `src/shared/lib/tokens.css` | exact match |
| Component code-connect | `**/*.figma.ts` | any depth, specific suffix |
| Tests only | `**/*.{test,spec}.ts` | two extensions, any tree |
| Config files | `{package,tsconfig,vite}.*` | multiple file prefixes |
| Cross-cutting pattern | `**/routes.{ts,js}` | same filename anywhere |

## Decision Table

| Rule covers | Scope this way |
| ---- | ---- |
| Project-wide conventions (naming, git) | no `paths:` — global |
| One module's internals | `<module>/**` |
| One technology's files | `**/*.<ext>` |
| One layer across modules | `**/layer-name/**` |
| One file type in one area | `area/**/*.<ext>` |
| A single canonical file | exact path |

## Gotchas

| Mistake | Symptom | Fix |
| ---- | ---- | ---- |
| Too-narrow glob | Rule never loads | Run `/validate-claude-docs .` — it flags zero-match globs |
| Too-broad glob (`**`) | Rule loads always, defeats scoping | Narrow by directory or extension |
| Leading `./` | Matching breaks in some runners | Use `src/**`, not `./src/**` |
| Absolute paths | Not supported | Always project-relative |
| Regex syntax (`.+`, `[a-z]`) | Not glob, silently fails | Use glob: `*`, `**`, `?`, `{a,b}` |
| Missing quotes | YAML parser eats special chars | Quote every glob: `"src/**/*.ts"` |
| Mixed case-sensitivity | OS-dependent matches | Prefer all-lowercase paths |

## Validation

```bash
# Does the glob actually match files in this project?
ls -la src/**/*.ts 2>/dev/null | head
```

Or from Claude:

```text
/validate-claude-docs .
```

Looks for each rule's `paths:` globs and reports match counts. Zero matches → `[WARN]` in the output.

## Context-Saving Math

Before scoping: every rule loads every session. N rules × avg 150 lines = 150N lines of context always consumed.

After scoping: only rules matching the current file's path load. Typically 2-4 rules per file → ~300-600 lines per session instead of 150N.

Measured savings on real projects: **40-80%** depending on how many rules were global vs conditional before.

## Related

- Full rule authoring: `docs/how-to-create-docs.md`
- Extracting sections from `CLAUDE.md` into scoped rules: same file, section "Pattern: Extract Workflow From CLAUDE.md Into a Scoped Rule"
- Automated validation: `/validate-claude-docs` + `/sleep`
